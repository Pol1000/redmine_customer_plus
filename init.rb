require 'redmine'
require 'customer_plus'
require 'customer_user_hooks'

Redmine::Plugin.register :redmine_customer_plus do
  name 'Redmine Customer Plus plugin'
  author 'Ivan Pirlik'
  description 'A plugin for giving a restricted view to customers'
  version '0.0.1'

User.safe_attributes 'customer_id'

  project_module :customer_issues do
    permission :view_customer_issues, {:customer_issues => [:show]}
    permission :list_customer_issues, {:customer_issues => [:list]}
    permission :edit_customer_issues, {:customer_issues => [:edit, :update, :new, :create, :destroy]}
    permission :view_customer_attachments, {:customer_attachments => [:show]}
  end
  project_module :customers do
    permission :view_customers, {:customer_plus => [:list, :show]}
    permission :edit_customers, {:customer_plus => [:edit, :update,  :create, :destroy]}
    permission :create_customers, {:customer_plus => [:new]}
  end
  menu :project_menu, :customer_issues, {:controller => 'customer_issues', :action => 'list'}, :caption => :customer_issues_title
  menu :project_menu, :customer_issues_new, {:controller => 'customer_issues', :action => 'new'}, :caption => :customer_issues_new_title
  menu :project_menu, :customers, {:controller => 'customer_plus', :action => 'list'}, :caption => :label_customer_list
  
  menu :top_menu, :customers, {:controller => 'customer_plus', :action => 'list'}, :class => "icon icon-groupusers" , :caption => :customer_plus_title, :if => lambda{ User.current.admin? }
  
  settings :default => {
       'statuses' => []
  }, :partial => 'settings/redmine_customer_plus_settings'
  

end

Mailer.view_paths.unshift(File.dirname(__FILE__)+'/app/views')


