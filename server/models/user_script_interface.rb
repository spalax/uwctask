class UserScriptInterface
  def initialize(scheduler, exchanger)
    @scheduler = scheduler
    project    = scheduler.project

    @script       = project.script_path
    @store        = StoreInterface.new(project)
    @project_data = ProjectDataInterface.new(project)

    @exchanger = exchanger
  end

  def _store
    @store
  end

  def _data
    @project_data
  end

  def _get_state
    return @current_state if @current_state

    _chunk_id, state = @scheduler.state.first
    @current_state = state
  end

  def _set_state(state)
    @current_state = state
  end

  def _wait_for_all
    Thread.new { sleep(0.5) while @scheduler.state.any? }.join
  end

  def _emit(position, data, processor, &callback)
    @store.presave(position)

    @exchanger.exchange({
      id: Digest::MD5.hexdigest(_get_state.to_s),
      state: _get_state,
      position: position,
      data: data,
      processor: processor,
      callback: callback
    })
  end

  def _finish(result)
    @exchanger.exchange({
      finish: true,
      result: result
    })
  end
end

class StoreInterface
  def initialize(project)
    @store = project.results
  end

  def presave(position)
    @store.insert() if @store.where(id: position).empty?
  end

  def save(position, value)
    @store.where(id: position).update value: value
  end

  def delete(ids)
    @store.where(id: ids).update value: nil
  end

  def length
    @store.where("value IS NOT NULL").count
  end

  def from(position, count)
    @store.where { id >= position }.where("value IS NOT NULL").order(:id).first(count)
  end

  def [](from, to = nil)
    if to.nil?
      @store.where(id: from).map(:value).first
    else
      @store.where(id: (from..to)).map(:value)
    end
  end
end

class ProjectDataInterface
  def initialize(project)
    if project.data_path
      @data = JSON.load(File.read(project.data_path))
    end
  end

  def [](from, to = nil)
    to.nil? ? @data[from] : @data[from..to]
  end

  def length
    @data.length
  end
end
