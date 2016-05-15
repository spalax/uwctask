Sequel.migration do
  change do
    create_table(:schedulers) do
      primary_key :id
      foreign_key :project_id, :projects, null: false
      index :project_id, unique: true

      String :state, text: true
    end
  end
end
