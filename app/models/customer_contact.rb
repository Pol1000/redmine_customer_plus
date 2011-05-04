class CustomerContact < ActiveRecord::Base
  belongs_to :customer
  validates_presence_of :name
  
  def pretty_name
    self.name
  end
  
end