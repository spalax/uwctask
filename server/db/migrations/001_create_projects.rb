Sequel.migration do
  change do
    create_table(:projects) do
      primary_key :id
      String :name, null: false
      String :script_path, null: false
      String :data_path
      TrueClass :finished, null: false, default: false
    end
  end
end
