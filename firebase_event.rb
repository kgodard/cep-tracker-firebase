class FirebaseEvent
  attr_reader :firebase, :firebase_uri, :firebase_secret

  def initialize(firebase_uri:, firebase_secret:)
    @firebase_uri = firebase_uri
    @firebase_secret = firebase_secret
    @firebase = Firebase::Client.new(firebase_uri, firebase_secret)
  end

  def search(params: {})
    abort("Empty params! #{params}") if params.empty?
    path = rest_request(params)
    events = JSON.parse `curl #{path}`
    return [] if events.nil?
    events.values.sort_by {|e| e['created_at']}
  rescue => e
    abort("Error fetching events from firebase: #{e.message}")
  end

  def create(params: {})
    abort("Empty params! #{params}") if params.empty?
    firebase.push( 'events', params )
  end

  def fetch(event_key:)
    firebase.get("events/#{event_key}")
  end

  private

  def rest_request(params)
    base = url_with_auth
    params.each do |k,v|
      base += "&#{k}=#{v}"
    end
    base.to_json
  end

  def url_with_auth
    "#{firebase_uri}/events.json?auth=#{firebase_secret}"
  end
end

# index, new, create, show, edit, update, delete
