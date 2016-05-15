class Result
  def self.assoc_id(project)
    "results_#{project.id}".to_sym
  end

  def self.create_dataset(project)
    DB.create_table(assoc_id(project)) do
      primary_key :id
      column :value, :longtext
    end
  end
end
