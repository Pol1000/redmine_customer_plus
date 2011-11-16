
class CustomerIssuesController < ApplicationController
  menu_item :new_issue, :only => :new
  default_search_scope :issues
  
  before_filter :find_issue, :only => [:show, :edit, :update, :reply]
  before_filter :find_issues, :only => [:bulk_edit, :move, :destroy]
  before_filter :find_project, :except => [:show, :update]
  before_filter :authorize, :except => [:preview]
  #before_filter :authorize, :except => [:index, :changes, :gantt, :calendar, :preview, :context_menu]
  before_filter :find_optional_project, :only => [:index, :changes, :gantt, :calendar]
  accept_key_auth :index, :show, :changes
   
   helper :journals
   helper :projects
   include ProjectsHelper   
   helper :custom_fields
   include CustomFieldsHelper
   helper :issue_relations
   include IssueRelationsHelper
   helper :watchers
   include WatchersHelper
   helper :attachments
   include AttachmentsHelper
   helper :customer_attachments
   include CustomerAttachmentsHelper
   helper :issues_list
   helper :application
   include ApplicationHelper
   helper :sort
   include SortHelper
   helper :issues
   include IssuesHelper
   helper :timelog
   include Redmine::Export::PDF
  
   verify :method => [:post, :delete],
          :only => :destroy,
          :render => { :nothing => true, :status => :method_not_allowed }
  
   verify :method => :put, :only => :update, :render => {:nothing => true, :status => :method_not_allowed }
  
  def list
    @fields = [:tracker, :status, :subject]
    @sort = {
      :tracker => "#{Tracker.table_name}.position",
      :status => "#{IssueStatus.table_name}.position",
      :subject => "#{Issue.table_name}.subject"
    }
    
    sort_init([['id', 'desc']] )
    sort_update({'id' => "#{Issue.table_name}.id"}.merge(@fields.inject({}) {|h, c| @sort[c]; h}))
    
    limit = case params[:format]
    when 'csv', 'pdf'
      Setting.issues_export_limit.to_i
    when 'atom'
      Setting.feeds_limit.to_i
    else
      per_page_option
    end
    
    cond = "#{Issue.table_name}.project_id = #{@project.id} AND ((#{Issue.table_name}.author_id = #{User.current.id})"
    
    
     @customer=Customer.find_by_id(User.current.customer_id)
     
     @id_custom=Setting["plugin_redmine_customer_plus"]['save_customer_to']
     if(@customer)
        cond+="OR ( '#{@customer.name.to_s}' IN (SELECT c.value FROM #{CustomValue.table_name} c WHERE c.custom_field_id = #{@id_custom} "
        cond+=" AND c.customized_type = 'Issue' AND c.customized_id = #{Issue.table_name}.id))"
     end

      
  
    cond+=")"
    
    
    cond += " OR (#{Issue.table_name}.id IN 
        (SELECT #{Watcher.table_name}.watchable_id FROM #{Watcher.table_name} 
        WHERE #{Watcher.table_name}.user_id = #{User.current.id} AND #{Watcher.table_name}.watchable_type = 'Issue'))"
    query = {
     
      :conditions => [cond],
      
    }
    @issue_count = Issue.count(query)
    @issue_pages = Paginator.new self, @issue_count, limit, params['page']

    @issues = Issue.find(:all, query.merge({
      :include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
      :order => sort_clause,
      :offset => @issue_pages.current.offset, 
      :limit => limit
    }))
    
    respond_to do |format|
      format.html { render :template => 'customer_issues/index.rhtml', :layout => !request.xhr? }
      format.xml  { render :layout => false }
      format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
      format.csv  { send_data(issues_to_csv(@issues, @project), :type => 'text/csv; header=present', :filename => 'export.csv') }
      format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => 'export.pdf') }
    end

  end
  

  
  def show
    @journals = @issue.journals.find(
        :all,
        :include => [:user, :details], 
        :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
    @journals = @journals.select{ |j| j.visible_to_current_customer? }
    @changesets = @issue.changesets.visible.all
    @changesets.reverse! if User.current.wants_comments_in_reverse_order?
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @priorities = IssuePriority.all
    @time_entry = TimeEntry.new
    respond_to do |format|
      format.html { render :template => 'customer_issues/show.rhtml' }
      format.xml  { render :layout => false }
      format.atom { render :action => 'changes', :layout => false, :content_type => 'application/atom+xml' }
      format.pdf  { send_data(issue_to_pdf(@issue), :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf") }
    end
  end

  def set_dummy_custom_fields(issue)
    issue.custom_field_values.each do |value|
        next if value.custom_field.visible_to_current_customer?
        if value.custom_field.is_required? && (!value.value || value.value.empty?)
            case value.custom_field.field_format
            when "date"
                value.value = Date.today
            when "text", "string"
                value.value = value.custom_field.default_value ? value.custom_field.default_value : "---"
            when "bool"
                value.value = false
            when "list"
                value.value = value.custom_field.default_value
            end
        end
    end
  end
  private :set_dummy_custom_fields

  # Add a new issue
  # The new issue will be created from an existing one if copy_from parameter is given
  def new
    @issue = Issue.new
    @issue.copy_from(params[:copy_from]) if params[:copy_from]
    @issue.project = @project
    # Tracker must be set before custom field values
    @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)
    if @issue.tracker.nil?
      render_error l(:error_no_tracker_in_project)
      return
    end
    if params[:issue].is_a?(Hash)
      @issue.safe_attributes = params[:issue]
      @issue.watcher_user_ids = params[:issue]['watcher_user_ids'] if User.current.allowed_to?(:add_issue_watchers, @project)
    end
    @issue.author = User.current

    
    default_status = IssueStatus.default
    unless default_status
      render_error l(:error_no_default_issue_status)
      return
    end    
    @issue.status = default_status
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current, true)
    
    @issue.start_date ||= Date.today
    if request.get? || request.xhr?
      #nothing
    else
      set_dummy_custom_fields(@issue)
      if User.current.customer_id && Setting["plugin_redmine_customer_plus"]['save_customer_to'].is_a?(Array)
          customer = Customer.find_by_id(User.current.customer_id)
          @issue.custom_field_values.each do |value|
              if Setting["plugin_redmine_customer_plus"]['save_customer_to'].include?(value.custom_field.id.to_s)
                  value.value = customer.name
              end
          end
      end
      requested_status = IssueStatus.find_by_id(params[:issue][:status_id])
      # Check that the user is allowed to apply the requested status
      @issue.status = (@allowed_statuses.include? requested_status) ? requested_status : default_status
      call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
      if @issue.save
        attachments = Attachment.attach_files(@issue, params[:attachments])
        render_attachment_warning_if_needed(@issue)
        flash[:notice] = l(:notice_successful_create)
        call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
        respond_to do |format|
          format.html {
            redirect_to(params[:continue] ? { :action => 'new', :tracker_id => @issue.tracker } :
                                            { :action => 'show', :id => @issue })
          }
          format.xml  { render :action => 'show', :status => :created, :location => url_for(:controller => 'issues', :action => 'show', :id => @issue) }
        end
        return
      else
        respond_to do |format|
          format.html { }
          format.xml  { render(:xml => @issue.errors, :status => :unprocessable_entity); return }
        end
      end
    end
    @priorities = IssuePriority.all
    render :layout => !request.xhr?
  end
  
  # Attributes that can be updated on workflow transition (without :edit permission)
  # TODO: make it configurable (at least per role)
  UPDATABLE_ATTRS_ON_TRANSITION = %w(status_id assigned_to_id fixed_version_id done_ratio) unless const_defined?(:UPDATABLE_ATTRS_ON_TRANSITION)
  
  def edit
    update_issue_from_params

    @journal = @issue.current_journal

    respond_to do |format|
      format.html { }
      format.xml  { }
    end
  end

  def update
    update_issue_from_params
    set_dummy_custom_fields(@issue)

    if @issue.save_issue_with_child_records(params, @time_entry)
      render_attachment_warning_if_needed(@issue)
      flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

      respond_to do |format|
        format.html { redirect_back_or_default({:action => 'show', :id => @issue}) }
        format.xml  { head :ok }
      end
    else
      render_attachment_warning_if_needed(@issue)
      flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?
      @journal = @issue.current_journal

      respond_to do |format|
        format.html { render :action => 'edit' }
        format.xml  { render :xml => @issue.errors, :status => :unprocessable_entity }
      end
    end
    
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    flash.now[:error] = l(:notice_locking_conflict)
    # Remove the previously added attachments if issue was not updated
    attachments[:files].each(&:destroy) if attachments[:files]
  end

  def reply
    journal = Journal.find(params[:journal_id]) if params[:journal_id]
    if journal
      user = journal.user
      text = journal.notes
    else
      user = @issue.author
      text = @issue.description
    end
    content = "#{ll(Setting.default_language, :text_user_wrote, user)}\\n> "
    content << text.to_s.strip.gsub(%r{<pre>((.|\s)*?)</pre>}m, '[...]').gsub('"', '\"').gsub(/(\r?\n|\r\n?)/, "\\n> ") + "\\n\\n"
    render(:update) { |page|
      page.<< "$('notes').value = \"#{content}\";"
      page.show 'update'
      page << "Form.Element.focus('notes');"
      page << "Element.scrollTo('update');"
      page << "$('notes').scrollTop = $('notes').scrollHeight - $('notes').clientHeight;"
    }
  end


  def update_form
    if params[:id].blank?
      @issue = Issue.new
      @issue.project = @project
    else
      @issue = @project.issues.visible.find(params[:id])
    end
    @issue.attributes = params[:issue]
    @allowed_statuses = ([@issue.status] + @issue.status.find_new_statuses_allowed_to(User.current.roles_for_project(@project), @issue.tracker)).uniq
    @priorities = IssuePriority.all
    
    render :partial => 'attributes'
  end
  
  def preview
    @issue = @project.issues.find_by_id(params[:id]) unless params[:id].blank?
    @attachements = @issue.attachments if @issue
    @text = params[:notes] || (params[:issue] ? params[:issue][:description] : nil)
    render :partial => 'common/preview'
  end
  
private
  def find_issue
    @issue = Issue.find(params[:id], :include => [:project, :tracker, :status, :author, :priority, :category])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  # Filter for bulk operations
  def find_issues
    @issues = Issue.find_all_by_id(params[:id] || params[:ids])
    raise ActiveRecord::RecordNotFound if @issues.empty?
    projects = @issues.collect(&:project).compact.uniq
    if projects.size == 1
      @project = projects.first
    else
      # TODO: let users bulk edit/move/destroy issues from different projects
      render_error 'Can not bulk edit/move/destroy issues from different projects'
      return false
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_project
    begin
      @project = Project.find(params[:id] || params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
  
  def find_optional_project
    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
    allowed = User.current.allowed_to?({:controller => params[:controller], :action => params[:action]}, @project, :global => true)
    allowed ? true : deny_access
  rescue ActiveRecord::RecordNotFound
    render_404
  end


  # Used by #edit and #update to set some common instance variables
  # from the params
  # TODO: Refactor, not everything in here is needed by #edit
  def update_issue_from_params
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @priorities = IssuePriority.all
    @edit_allowed = User.current.allowed_to?(:edit_customer_issues, @project)
    @time_entry = TimeEntry.new
    
    @notes = params[:notes]
    @issue.init_journal(User.current, @notes)
    # User can change issue attributes only if he has :edit permission or if a workflow transition is allowed
    if (@edit_allowed || !@allowed_statuses.empty?) && params[:issue]
      attrs = params[:issue].dup
      attrs.delete_if {|k,v| !UPDATABLE_ATTRS_ON_TRANSITION.include?(k) } unless @edit_allowed
      attrs.delete(:status_id) unless @allowed_statuses.detect {|s| s.id.to_s == attrs[:status_id].to_s}
      @issue.safe_attributes = attrs
    end

  end
end
