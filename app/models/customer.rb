class Customer < ActiveRecord::Base
  has_many :users
  has_many :contacts, :class_name => 'CustomerContact'
  has_and_belongs_to_many :projects
  
  
  # name or company is mandatory
  validates_presence_of :name

  validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, 
    :allow_nil => true, :allow_blank => true
  #TODO validate website address
  #TODO validate skype_name contact
  
   def pretty_name
     result = []
     [self.name].each do |field|
       result << field unless field.blank?
     end
     
     return result.join(", ")
   end
  
  private
  
  def name_unsetted
    self.name.blank?
  end
  
  
end

