# Use rake db:migrate_plugins to migrate installed plugins

class Aziende < ActiveRecord::Migration
  def self.up
    unless check_table(:aziendes)
      create_table :aziendes do |t|
        t.column :ragSociale, :string
    end
  end
  
  
   add_column :customers, :azienda, :integer
  
   execute <<-SQL
      ALTER TABLE customers
        ADD CONSTRAINT fk_01_cliente_di
        FOREIGN KEY (azienda)
        REFERENCES aziendes(id)
    SQL
  end
  
  
  
  
  
   def self.down
     
    execute "ALTER TABLE customers DROP FOREIGN KEY fk_01_cliente_di"
    
    remove_column :customer, :azienda
    
    drop_table :aziende
    
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