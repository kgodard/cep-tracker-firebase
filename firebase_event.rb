class FirebaseEvent
  DEBUG = false
  attr_reader :firebase, :firebase_uri, :firebase_secret

  def initialize(firebase_uri:, firebase_secret:)
    @firebase_uri = firebase_uri
    @firebase_secret = firebase_secret
    @firebase = Firebase::Client.new(firebase_uri, firebase_secret)
  end

  def search(params: {})
    puts "DEBUG: SEARCH #{params.inspect}" if DEBUG
    abort("Empty params! #{params}") if params.empty?
    path = rest_request(params)
    events = JSON.parse fb_search(path)
    return [] if events.nil?
    events.values.sort_by {|e| e['created_at']}
  rescue => e
    abort("Error fetching events from firebase: #{e.message}")
  end

  def create(params: {})
    puts "DEBUG: CREATE #{params.inspect}" if DEBUG
    abort("Empty params! #{params}") if params.empty?
    fb_push_event(params)
  end

  def fetch(event_key:)
    puts "FETCH: EVENT_KEY: #{event_key}" if DEBUG
    fb_fetch_event(event_key)
  end

  private

  def fb_fetch_event(event_key)
    suppress_output { firebase.get("events/#{event_key}") }
  end

  def fb_push_event(params)
    suppress_output { firebase.push( 'events', params ) }
  end

  def fb_search(path)
    suppress_output { `curl #{path}` }
  end

  def suppress_output
    print ' '
    original_stdout, original_stderr = $stdout.clone, $stderr.clone
    $stderr.reopen File.new('/dev/null', 'w')
    $stdout.reopen File.new('/dev/null', 'w')
    yield
  ensure
    $stdout.reopen original_stdout
    $stderr.reopen original_stderr
  end

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
