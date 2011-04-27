module CustomerIssuesHelper
   def render_customer_custom_fields_rows(issue)
     return if issue.custom_field_values.empty?
     values = issue.custom_field_values.select{ |v| v.custom_field.visible_to_current_customer? }
     return if values.empty?
     ordered_values = []
     half = (values.size / 2.0).ceil
     half.times do |i|
       ordered_values << values[i]
       ordered_values << values[i + half]
     end
     s = "<tr>\n"
     n = 0
     ordered_values.compact.each do |value|
       s << "</tr>\n<tr>\n" if n > 0 && (n % 2) == 0
       s << "\t<th>#{ h(value.custom_field.name) }:</th><td>#{ simple_format_without_paragraph(h(show_value(value))) }</td>\n"
       n += 1
     end
     s << "</tr>\n"
     s
   end 
end