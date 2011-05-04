# Use rake db:migrate_plugins to migrate installed plugins

class CampiClienteSintecop < ActiveRecord::Migration
  def self.up
    add_column :customers, :teleassistenza,                 :boolean
    add_column :customers, :teleassistenza_sistemistica,    :boolean 
    add_column :customers, :contratto_manutenzione,         :boolean 
    add_column :customers, :manutenzione_sistemistica,      :boolean     
  end

  def self.down
      remove_column :customers, :teleassistenza
      remove_column :customers, :teleassistenza_sistemistica
      remove_column :customers, :contratto_manutenzione 
      remove_column :customers, :manutenzione_sistemistica
  end
end
