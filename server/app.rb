class App < Sinatra::Base
  configure do
    enable :logging
    use Rack::CommonLogger, LOGGER
  end

  before do
    if project_name = params[:project]
      @project = Project.find(name: project_name)
      @scheduler = Scheduler.instance(@project) if @project
    end
  end

  helpers do
    def schedule_work(client_id)
      chunk = @scheduler.schedule(params[:client_id])
      chunk == :finished ? JSON.dump(finish: true) : JSON.dump(chunk)
    end
  end

  get '/' do
    'Welcome to Grid!'
  end

  get '/list' do
    Project.map(:name).to_json
  end

  post '/create' do
    Project::Importer.create(params)
    200
  end

  get '/work' do
    schedule_work(params[:client_id])
  end

  post '/result' do
    result = params[:result]
    @scheduler.processed(params[:client_id], result)
    Client.add_rating(params[:client_id])

    schedule_work(params[:client_id])
  end

  post '/alive' do
    @scheduler.touch(params[:client_id])
  end
end
