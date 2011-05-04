
# Use rake db:migrate_plugins to migrate installed plugins
class LinkProjectsToCustomers < ActiveRecord::Migration
  def self.up
    create_table "customers_projects", :id => false do |t|
      t.column "customer_id", :integer, :null => false
      t.column "project_id", :integer, :null => false
    end
  end

  def self.down
    drop_table :customers_projects
  end
end
