require 'concurrent/exchanger'

class Scheduler < Sequel::Model
  ACTIVE_CLIENT_TIMEOUT = 120 # 2 minutes

  many_to_one :project
  plugin :serialization, :marshal, :state

  def self.instance(project)
    @instances ||= {}

    @instances[project.id] || begin
      scheduler = Scheduler.find_or_create(project_id: project.id)
      scheduler.init
      @instances[project.id] = scheduler
    end
  end

  def init
    @exchanger = Concurrent::Exchanger.new
    @user_script_interface = UserScriptInterface.new(self, @exchanger)
    start_user_script

    schedule_clean_hanging_jobs

    @processing, @pending, @callbacks, @active_clients = {}, [], {}, {}
    self.state ||= {}

    @mutex = Mutex.new
  end

  def schedule(client_id)
    @mutex.synchronize do
      return @processing[client_id] if @processing[client_id]
      return :finished if self.project.reload.finished

      chunk = if @pending.any?
        @pending.shift
      else
        chunk = @exchanger.exchange(:next_chunk)
        if chunk[:finish]
          self.project.update finished: true
          return :finished
        end

        next_chunk = chunk.slice(:id, :data, :processor)
        @callbacks[next_chunk[:id]] = chunk.slice(:position, :callback)
        update_state { state[next_chunk[:id]] = chunk[:state] }

        next_chunk
      end

      @processing[client_id] = chunk
      @active_clients[client_id] = Time.now

      chunk
    end
  end

  # mark chunk as processed only if callback exists;
  # if there was an outage, @processing array is empty,
  #   so next client will pick this chunk up and no data will be lost
  def processed(client_id, result)
    return if self.project.reload.finished

    chunk = @processing[client_id]

    if chunk && callback_meta = @callbacks[chunk[:id]]
      callback_meta[:callback].call(callback_meta[:position], result)
      @processing.delete(client_id)
      update_state { state.delete(chunk[:id]) }
    end
  end

  def touch(client_id)
    @active_clients[client_id] = Time.now
  end

  private

  def update_state
    result = yield
    self.save columns: %i(state)

    result
  end

  def start_user_script
    t = Thread.new do
      script = File.read(self.project.script_path)
      @user_script_interface.instance_eval script, self.project.script_path
    end

    t.abort_on_exception = true
  end

  def schedule_clean_hanging_jobs
    Thread.new do
      loop do

        sleep ACTIVE_CLIENT_TIMEOUT
        current = Time.now

        @active_clients.each do |client_id, timestamp|

          if current - timestamp > ACTIVE_CLIENT_TIMEOUT
            processing = @processing.delete(client_id)
            @pending << processing if processing
            @active_clients.delete(client_id)
          end

        end

      end # loop do
    end # Thread.new
  end
end
