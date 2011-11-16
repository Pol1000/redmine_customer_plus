class CustomerUserHooks < Redmine::Hook::ViewListener
    
    def view_users_form(params)
        html = ""
        html += "<p>"
        html += params[:form].select :customer_id, Customer.find(:all).collect{ |c| [c.name, c.id]}, :include_blank => true
        html += "</p>"
        html
        # user = params[:user]
        # "ciao"
    end
    
    
    
    def view_issues_form_details_top(params)
      
     @issue = params[:issue]
      if(params[:customer])
      @customer= Customer.find_by_id(params[:customer])
      
       @issue.custom_field_values.each do |value|
              if Setting["plugin_redmine_customer_plus"]['save_customer_to'].include?(value.custom_field.id.to_s)
                  value.value = @customer.name
              end
          end
      end
  end
  
  
  
  def view_issues_show_details_bottom(params)
    @issue = Issue.find_by_id(params[:issue])
    
    if @issue.project.module_enabled?(:customers)
      html = ""
      html += "<tr>"
      html += link_to("vedi cliente", {:controller => 'customer_plus', :action => 'go_to_customer', :issue => @issue}, :class => 'icon icon-checked' )
      html += "</tr>"
      html
    end
  end



 
end