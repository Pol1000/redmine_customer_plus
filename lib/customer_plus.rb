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
      send_mail =  shown_changes['mail']
      return true if details.empty? && shown_changes['just_comments'] && send_mail
      return true if has_visible_to_customer_detail? && send_mail
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
      if journal.visible_to_customer?
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
      
end




