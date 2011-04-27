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
    
end