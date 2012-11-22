module RedmineCustomerPlus
  
  module CustomerPlusMailer
    def issue_edit(journal)
      super
    end
  end
  
  JournalDetail.class_eval do
    def visible_to_customer?
      shown_statuses = Setting["plugin_redmine_customer_plus"]["statuses"] || []
      shown_journal_details = Setting["plugin_redmine_customer_plus"]["changes"] || {}
      if property == 'attr'
        return false if prop_key == 'status_id' && !shown_statuses.include?(value.to_s)
        return false if prop_key != 'status_id' && !shown_journal_details.keys.include?(prop_key)
        return true
      elsif property == 'attachment'
        return false unless shown_journal_details['attachment']
        return true
      end
      return false
    end
    alias :visible_to_current_customer? :visible_to_customer?
    
  end

  Journal.class_eval do

    def has_visible_to_customer_detail?
      !details.select{ |d| d.visible_to_customer? }.empty?
    end

    def visible_to_customer?
      shown_changes = Setting["plugin_redmine_customer_plus"]["changes"] ||= {}
#      send_mail =  shown_changes['mail']
      return true if details.empty? && shown_changes['just_comments']
      return true if has_visible_to_customer_detail?
      return false
    end
    
    def visible_to_current_customer?
        return true if user_id == User.current.id
        return self.visible_to_customer?
    end
  end

  Mailer.class_eval do

    def issue_edit_for_customers(journal)
      issue = journal.journalized.reload
      redmine_headers 'Project' => issue.project.identifier,
                      'Issue-Id' => issue.id,
                      'Issue-Author' => issue.author.login
      redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to     
      message_id journal
      references issue
      @author = journal.user
       shown_changes = Setting["plugin_redmine_customer_plus"]["changes"] ||= {}
      send_mail =  shown_changes['mail']
      if journal.visible_to_customer?
        if send_mail
        notified = issue.project.notified_users
        # Author and assignee are always notified unless they have been locked
        notified << issue.author if issue.author && issue.author.active?
        notified << issue.assigned_to if issue.assigned_to && issue.assigned_to.active?
        notified.uniq!
        # Remove users that can not view the issue
        notified.reject! {|user| !user.allowed_to?(:view_customer_issues, issue.project)}
        recipients notified.collect(&:mail)
        # Watchers
        notified = issue.watchers.collect(&:user).select(&:active?)
        notified.reject! {|user| !user.allowed_to?(:view_customer_issues, issue.project) }
        cc (notified.collect(&:mail).compact - @recipients)
        end
      end
      s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
      s << "(#{issue.status.name}) " if journal.new_value_for('status_id')
      s << issue.subject
      subject s
      body :issue => issue,
           :journal => journal,
           :issue_url => url_for(:controller => 'customer_issues', :action => 'show', :id => issue)

      render_multipart('issue_edit_for_customer', body)
    end



  end


  JournalObserver.class_eval do

    alias :customer_plus_old_after_create :after_create
    def after_create(journal)
      customer_plus_old_after_create(journal)
      Mailer.deliver_issue_edit_for_customers(journal) if Setting.notified_events.include?('issue_updated')
    end


  end
  
  IssueCustomField.class_eval do
      def visible_to_customer?
        Setting["plugin_redmine_customer_plus"]["custom_fields"] ||= []
        Setting["plugin_redmine_customer_plus"]["custom_fields"].include?(self.id.to_s)
      end
      alias :visible_to_current_customer? :visible_to_customer?
    
  end
  
  
  SearchController.class_eval do
   def index
    @question = params[:q] || ""
    @question.strip!
    @all_words = params[:all_words] ? params[:all_words].present? : true
    @titles_only = params[:titles_only] ? params[:titles_only].present? : false

    projects_to_search =
      case params[:scope]
      when 'all'
        nil
      when 'my_projects'
        User.current.memberships.collect(&:project)
      when 'subprojects'
        @project ? (@project.self_and_descendants.active) : nil
      else
        @project
      end

    offset = nil
    begin; offset = params[:offset].to_time if params[:offset]; rescue; end

    # quick jump to an issue
    
        if User.current.customer_id 
              if @question.match(/^#?(\d+)$/) && Issue.find_by_id($1.to_i)
                 @foundIssue= Issue.find_by_id($1.to_i)
                 @currentCustomer = Customer.find_by_id(User.current.customer_id)
        
                 @foundIssue.custom_field_values.each do |value|
                  if Setting["plugin_redmine_customer_plus"]['save_customer_to'].include?(value.custom_field.id.to_s)
                       @customer = Customer.find(:all, :conditions => {:name => value.value })
                       @customer.each do |custom|
                           if(custom.name == @currentCustomer.name)
                               redirect_to :controller => "customer_issues", :action => "show", :id => $1
                            return
                          end
                      end
                end
                end
            end
        else
            if @question.match(/^#?(\d+)$/) && Issue.visible.find_by_id($1.to_i)
               redirect_to :controller => "issues", :action => "show", :id => $1
                return
            end
    end

    @object_types = Redmine::Search.available_search_types.dup
    if projects_to_search.is_a? Project
      # don't search projects
      @object_types.delete('projects')
      # only show what the user is allowed to view
      @object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
    end

    @scope = @object_types.select {|t| params[t]}
    @scope = @object_types if @scope.empty?

    # extract tokens from the question
    # eg. hello "bye bye" => ["hello", "bye bye"]
    @tokens = @question.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
    # tokens must be at least 2 characters long
    @tokens = @tokens.uniq.select {|w| w.length > 1 }

    if !@tokens.empty?
      # no more than 5 tokens to search for
      @tokens.slice! 5..-1 if @tokens.size > 5

      @results = []
      @results_by_type = Hash.new {|h,k| h[k] = 0}

      limit = 10
      @scope.each do |s|
        r, c = s.singularize.camelcase.constantize.search(@tokens, projects_to_search,
          :all_words => @all_words,
          :titles_only => @titles_only,
          :limit => (limit+1),
          :offset => offset,
          :before => params[:previous].nil?)
        @results += r
        @results_by_type[s] += c
      end
      @results = @results.sort {|a,b| b.event_datetime <=> a.event_datetime}
      if params[:previous].nil?
        @pagination_previous_date = @results[0].event_datetime if offset && @results[0]
        if @results.size > limit
          @pagination_next_date = @results[limit-1].event_datetime
          @results = @results[0, limit]
        end
      else
        @pagination_next_date = @results[-1].event_datetime if offset && @results[-1]
        if @results.size > limit
          @pagination_previous_date = @results[-(limit)].event_datetime
          @results = @results[-(limit), limit]
        end
      end
    else
      @question = ""
    end
    render :layout => false if request.xhr?
  end
end



end




