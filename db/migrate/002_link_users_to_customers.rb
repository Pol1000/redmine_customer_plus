
# Use rake db:migrate_plugins to migrate installed plugins
class LinkUsersToCustomers < ActiveRecord::Migration
  def self.up
    add_column :users, :customer_id, :integer    
  end

  def self.down
    remove_column :users, :customer_id
  end
end
