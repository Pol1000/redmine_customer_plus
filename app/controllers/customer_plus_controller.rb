class CustomerPlusController < ApplicationController
  layout 'base'
  before_filter :find_project, :except => [:autocomplete_for_project, :autocomplete_for_user, :add_users, :remove_user,
      :add_projects, :remove_project] #, :authorize
  
    
  def list
    
    if (@project)
       conditions = ["customers_projects.project_id = '?'", @project.id]
    else
       if(params[:name])
        unless params[:name].blank?
          name = "%#{params[:name].strip.downcase}%"
          @current_letter =" "
          conditions = ["LOWER(customers.name) LIKE ?",name]
        end
        
       else        
       @current_letter = params[:letter] || 'A'
       conditions = ["UPPER(customers.name) like '#{@current_letter}%%'"]
      end
  
    end
       
    @customers = Customer.find(:all, :include => [:projects], :conditions => conditions, :order => "customers.name asc") || []
  end
  
  def show
    @customer = Customer.find_by_id(params[:customer_id])
    @azienda = Aziende.find_by_id(@customer.azienda)
    if(@azienda)
    
      @aziendaCorrelata = @azienda.ragSociale
    end
  end
  
  def edit
    @customer = Customer.find_by_id(params[:customer_id])
  end
  
  def create_issue
   @customer = Customer.find(params[:customer])
   @progetti_cliente = @customer.projects
   
   if @progetti_cliente.size == 1
         @selected = @progetti_cliente[0]
         @selected_id = @selected.id
       redirect_to :action => 'confermate_create',:customer =>@customer, :selected_id=>@selected_id
 
   else
      respond_to do |format|
          format.html { render :template => 'customer_plus/elenco_progetti', :layout => !request.xhr? }
        
     end
   end
 end
 
  def confermate_create
   @customer = params[:customer]
   @progetto = Project.find_by_id(params[:selected_id])
   if(@progetto)
      redirect_to :controller => 'issues', :action => 'new', :project_id =>@progetto, :customer => @customer
   else
     redirect_to :controller =>'customer_plus',:action=>'create_issue', :customer =>@customer
  end
  end
  # def select
  #   @customers = Customer.find(:all)
  # end
  
  def update
    @customer = Customer.find_by_id(params[:customer_id])
    if @customer.update_attributes(params[:customer])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => "list", :id => params[:id]
    else
      render :action => "edit", :id => params[:id]
    end
  end
  
  def destroy
    @customer = Customer.find_by_id(params[:customer_id])
    if @customer.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:notice_unsuccessful_save)
    end
    redirect_to :action => "list", :id => params[:id]
  end
  
  def new
    @customer = Customer.new
  end
  
  def create
    @customer = Customer.new(params[:customer])
    if @customer.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => "list", :id => params[:id]
    else
      render :action => "new", :id => params[:id]
    end
  end
  
  def add_users
    @customer = Customer.find(params[:id])
    users = User.find_all_by_id(params[:user_ids])
    @customer.users << users if request.post?
    respond_to do |format|
      format.html { redirect_to :controller => 'customer_plus', :action => 'edit', :id => @customer, :tab => 'users' }
      format.js { 
        render(:update) {|page| 
          page.replace_html "tab-content-users", :partial => 'customer_plus/users'
          users.each {|user| page.visual_effect(:highlight, "user-#{user.id}") }
        }
      }
    end
  end
  
  def remove_user
    @customer = Customer.find(params[:id])
    @customer.users.delete(User.find(params[:user_id])) if request.post?
    respond_to do |format|
      format.html { redirect_to :controller => 'customer_plus', :action => 'edit', :id => @customer, :tab => 'users' }
      format.js { render(:update) {|page| page.replace_html "tab-content-users", :partial => 'customer_plus/users'} }
    end
  end
  
  def autocomplete_for_user
    @customer = Customer.find(params[:id])
    @users = User.active.like(params[:q]).find(:all, :limit => 100) - @customer.users
    render :layout => false
  end
  
  def add_projects
    @customer = Customer.find(params[:id])
    projects = Project.find_all_by_id(params[:project_ids])
    @customer.projects << projects if request.post?
    respond_to do |format|
      format.html { redirect_to :controller => 'customer_plus', :action => 'edit', :id => @customer, :tab => 'projects' }
      format.js { 
        render(:update) {|page| 
          page.replace_html "tab-content-projects", :partial => 'customer_plus/projects'
          projects.each {|project| page.visual_effect(:highlight, "project-#{project.id}") }
        }
      }
    end
  end
  
  def remove_project
    @customer = Customer.find(params[:id])
    @customer.projects.delete(Project.find(params[:project_id])) if request.post?
    respond_to do |format|
      format.html { redirect_to :controller => 'customer_plus', :action => 'edit', :id => @customer, :tab => 'projects' }
      format.js { render(:update) {|page| page.replace_html "tab-content-projects", :partial => 'customer_plus/projects'} }
    end
  end
  
  def autocomplete_for_project
    @customer = Customer.find(params[:id])
    conditions = []
    if params[:q] && !params[:q].empty?
      customer_projects = @customer.projects
      q = '%%'+(params[:q] || "").upcase+'%%'
      conditions << "UPPER(#{Project.table_name}.name) LIKE '#{q}' "
      @projects = Project.find(:all, :conditions => conditions, :limit => 100)
      @projects = @projects - customer_projects
    else
      @projects = Project.find(:all, :limit => 100) - @customer.projects
    end
    render :layout => false
  end
  
  def find_project
    @project = Project.find(params[:id]) if params[:id]
  end
  
  def contact_new
    @customer = Customer.find(params[:customer_id])
    @customer_contact = CustomerContact.new
    @customer_contact.customer_id = params[:customer_id]
  end
  
  def contact_create
    @contact = CustomerContact.new(params[:customer_contact])
    if @contact.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => "edit", :customer_id => params[:customer_contact][:customer_id]
    else
      render :action => "new", :custmer_id => params[:customer_contact][:customer_id]
    end
  end
  
  
  
    def customer_issue
      
    
    cond=""
     @customer=Customer.find(params[:customer])
     
     @id_custom=Setting["plugin_redmine_customer_plus"]['save_customer_to']
     if(@customer)
        cond+=" ( '#{@customer.name.to_s}' IN (SELECT c.value FROM #{CustomValue.table_name} c WHERE c.custom_field_id = #{@id_custom} "
        cond+=" AND c.customized_type = 'Issue' AND c.customized_id = #{Issue.table_name}.id))"
     end
    

   
    query = {
     
      :conditions => [cond],
      
    }

    @customerIssues = Issue.find(:all, query.merge({
      :include => [:assigned_to, :tracker, :priority, :category, :fixed_version]
    }))
      
         respond_to do |format|
        format.html { render :template => 'customer_plus/elenco_issue', :layout => !request.xhr? }
        end
    end
  
  
  
  
  def contact_update
    @customer = Customer.find_by_id(params[:customer_contact][:customer_id])
    @contact = CustomerContact.find_by_id(params[:customer_contact][:id])    
    if @contact.update_attributes(params[:customer_contact])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => "edit", :customer_id => params[:customer_contact][:customer_id]
    else
      render :action => "customer_edit", :id => params[:id]
    end
  end
  
  def contact_show
    @customer = Customer.find_by_id(params[:customer_id])
    @customer_contact = CustomerContact.find_by_id(params[:contact_id])
  end
  
  def contact_edit
    @customer_contact = CustomerContact.find_by_id(params[:contact_id])
    @customer = Customer.find_by_id(@customer_contact.customer_id)
  end
  
  def contact_destroy
    @contact = CustomerContact.find_by_id(params[:contact_id])
    if @contact.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:notice_unsuccessful_save)
    end
    redirect_to :action => "edit", :customer_id => params[:customer_id]
  end
  
  
  def go_to_customer
  
   @issue = Issue.find_by_id(params[:issue])
  
   @issue.custom_field_values.each do |value|
              if Setting["plugin_redmine_customer_plus"]['save_customer_to'].include?(value.custom_field.id.to_s)
                  @customer = Customer.find(:all, :conditions => {:name => value.value })
                  if(@customer)
                  
                    redirect_to :action => "show", :customer_id =>@customer
                  end
              end
          end
  
end



  def gestione_aziende
    
     respond_to do |format|
        format.html { render :template => 'settings/gestione_aziende', :layout => !request.xhr? }
        end
  end



 def edit_azienda
         @edit_azienda = Aziende.find_by_id(params[:id])
        
     end

      def new_azienda
        @azienda = Aziende.new
      end
  
    def create_azienda
     @azienda = Aziende.new(params[:azienda])
      if @azienda.save
        flash[:notice] = l(:notice_successful_create)
       redirect_to :controller => 'customer_plus', :action => 'gestione_aziende'
       else
      render :action => 'new_azienda'
      end   
    end


  def update_azienda
    @azienda = Aziende.find_by_id(params[:id])
    if request.post? and @azienda.update_attributes(params[:azienda])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => "gestione_aziende"
    else
      render :action => "edit_azienda", :id => params[:id]
    end
  end


   def destroy_azienda
   @azienda = Aziende.find_by_id(params[:id])
    if @azienda.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:notice_unsuccessful_save)
    end
    redirect_to :controller => 'customer_plus', :action => 'gestione_aziende'
    end

  
end
