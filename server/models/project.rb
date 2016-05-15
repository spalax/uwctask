class Project < Sequel::Model
  one_to_one :scheduler

  def results
    DB[Result.assoc_id(self)]
  end

  class Importer
    def self.create(params)
      name   = params[:project]
      script = params[:script][:tempfile]
      data   = params[:data][:tempfile] if params[:data] && !params[:data].empty?

      script_path = File.absolute_path("./scripts/#{name}.rb")
      File.write script_path, script.read

      if data
        data_path = File.absolute_path("./data/#{name}")
        File.write data_path, data.read
      end

      project = Project.create(name: name, script_path: script_path, data_path: data_path)
      Result.create_dataset(project)

      project
    end
  end

end
