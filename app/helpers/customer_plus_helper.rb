module CustomerPlusHelper
  
  def customer_settings_tabs
    tabs = [{:name => 'details', :partial => 'customer_plus/details', :label => :label_details},
            {:name => 'contacts', :partial => 'customer_plus/contacts', :label => :label_customer_contacts},
            {:name => 'users', :partial => 'customer_plus/users', :label => :label_user_plural},
            {:name => 'projects', :partial => 'customer_plus/projects', :label => :label_project_plural}
            ]
  end
  
  def link_to_if_authorized_g(name, options = {}, html_options = nil, *parameters_for_method_reference)
    link_to(name, options, html_options, *parameters_for_method_reference) if User.current.admin? || authorize_for(options[:controller] || params[:controller], options[:action])
  end
  
end