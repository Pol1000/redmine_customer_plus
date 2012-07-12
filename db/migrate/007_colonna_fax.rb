# Use rake db:migrate_plugins to migrate installed plugins

class ColonnaFax < ActiveRecord::Migration
  def self.up
    add_column :customers, :fax, :string, :null => false, :default => ''
  end
  
  
  def self.down
      remove_column :customers, :fax
 end
end
