# Use rake db:migrate_plugins to migrate installed plugins
class CreateCustomers < ActiveRecord::Migration
  def self.up
    unless check_table(:customers)
      create_table :customers do |t|
        t.column :name, :string
        t.column :address, :text
        t.column :phone, :string
        t.column :email, :string
        t.column :website, :string
      end
    end
  end

  def self.down
    drop_table :customers
  end

  def self.check_table(name)
    begin
      User.connection.execute("select 1 from #{name}")
      return true;
    rescue
      return false;
    end
  end
end
