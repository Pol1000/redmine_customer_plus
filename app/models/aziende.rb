class Aziende < ActiveRecord::Base
  
  validates_presence_of :ragSociale
  
   def self.findAll
    Aziende.find(:all)
    end

end
