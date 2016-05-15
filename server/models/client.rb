class Client < Sequel::Model
  plugin :update_or_create

  def self.add_rating(client_id)
    client = self.find_or_new(client_id: client_id)
    client.rating = 0 if client.new?
    client.rating += 1
    client.save
  end
end
