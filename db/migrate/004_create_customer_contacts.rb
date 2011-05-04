# Use rake db:migrate_plugins to migrate installed plugins
class CreateCustomerContacts < ActiveRecord::Migration
  def self.up
    create_table :customer_contacts do |t|
      t.column :customer_id, :integer
      t.column :field, :string
      t.column :name, :string
      t.column :address, :text
      t.column :phone, :string
      t.column :email, :string
    end
  end

  def self.down
    drop_table :customer_contacts
  end

end
