#!/usr/bin/env ruby

#########################################################
# Client
#########################################################

require 'securerandom'
require 'rest-client'


class Client
  SERVER_IP = 'http://localhost:3000'
  ACTIVE_TIMEOUT = 60

  def initialize
    @id = SecureRandom.uuid
  end

  def list
    RestClient.get "#{SERVER_IP}/list"
  end

  def create(project_name, script, data)
    RestClient.post("#{SERVER_IP}/create",
      client_id: @id,
      project: project_name,
      script: script,
      data: data
    )
  end

  def get_chunk(project)
    response = RestClient.get("#{SERVER_IP}/work", params: { client_id: @id, project: project })
    schedule_active_requests(project)

    JSON.parse(response)
  end

  def send_result(project, result)
    response = RestClient.post("#{SERVER_IP}/result",
      client_id: @id,
      project: project,
      result: JSON.dump(result)
    )

    JSON.parse(response)
  end

  private

  def read_or_create_uuid
    file_path = '.client_id'

    return File.read(file_path) if File.exists?(file_path)

    uuid = SecureRandom.uuid
    File.write(file_path, uuid)
    uuid
  end

  def schedule_active_requests(project)
    return if @scheduled

    Thread.new do
      loop do
        sleep ACTIVE_TIMEOUT
        RestClient.post "#{SERVER_IP}/alive", client_id: @id, project: project
      end
    end

    @scheduled = true
  end
end

#########################################################
# Worker
#########################################################

class Worker
  def self.process(chunk)
    processor, data = chunk['processor'], chunk['data']
    eval(processor).call(data)
  end
end

#
#########################################################
#

require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: grid.rb [options]"

  opts.on("--list", "List available projects") { options[:list] = true }
  opts.on("--create", "Create a project") { options[:create] = true }
  opts.on("--name [PROJECT]", "Project name") { |name| options[:project] = name }
  opts.on("--script [FILE]", "Upload a script to process") { |path| options[:script] = File.new(path, 'rb') }
  opts.on("--data [FILE]", "Upload data file") { |path| options[:data] = File.new(path, 'rb') }
  opts.on("--work [PROJECT]", "Start processing") { |project| options[:work] = project }
end.parse!

client = Client.new

if options[:list]
  puts JSON.parse(client.list).join("\n")

elsif options[:create]
  client.create(options[:project], options[:script], options[:data])

elsif project = options[:work]
  chunk = client.get_chunk(project)

  loop do
    if chunk['finish']
      puts 'Finished!'
      break
    end

    result = Worker.process(chunk)
    chunk = client.send_result(project, result)
  end
end
