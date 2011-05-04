module IssuesListHelper
  def column_content(column, issue)
    value = issue.send(column)
    name = column.to_sym
    case value.class.name
    when 'String'
      if name == :subject
        link_to(h(value), :controller => 'customer_issues', :action => 'show', :id => issue)
      else
        h(value)
      end
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Fixnum', 'Float'
      if name == :done_ratio
        progress_bar(value, :width => '80px')
      else
        value.to_s
      end
    when 'User'
      link_to_user value
    when 'Project'
      link_to(h(value), :controller => 'projects', :action => 'show', :id => value)
    when 'Version'
      link_to(h(value), :controller => 'versions', :action => 'show', :id => value)
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    else
      h(value)
    end
  end
end