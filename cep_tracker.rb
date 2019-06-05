class CepTracker

  EVENTS = {
    start: {
      requires_a_reason: false,
      allowed_next: [:finish, :stop, :block]
    },
    finish: {
      requires_a_reason: false,
      allowed_next: [:reject]
    },
    resume: {
      requires_a_reason: false,
      allowed_next: [:finish, :stop, :block]
    },
    restart: {
      requires_a_reason: false,
      allowed_next: [:finish, :stop, :block]
    },
    stop: {
      requires_a_reason: true,
      allowed_next: [:resume]
    },
    block: {
      requires_a_reason: true,
      allowed_next: [:resume]
    },
    reject: {
      requires_a_reason: true,
      allowed_next: [:restart]
    }
  }

  REASONS = %w[ bug cep hardware firmware devops it bad_ac qa priority_change other ].map(&:upcase)

  LOCAL_SETTINGS_FILE = 'ctf_settings.yml'

  attr_reader :firebase, :options, :parser, :local_settings, :ads_story

  def initialize(args)
    @options        = ScriptOptions.new
    @local_settings = load_local_settings
    @firebase       = Firebase::Client.new(firebase_uri, firebase_secret)
    option_parser.parse!(args)
    get_inputs
    perform_ads_story_action
    perform_firebase_action
  end

  def option_parser
    @parser ||= OptionParser.new do |parser|
      parser.banner = "Usage: ctf [options]"
      parser.separator ""
      parser.separator "Specific options:"

      # additional options
      parser.on("-t", "--tracker TRACKERID", "specify story id") do |tracker_id|
        set_tracker_id(tracker_id)
      end

      parser.on("-p", "--points POINTS", "specify story points") do |points|
        options.points = points
      end

      parser.on("-e", "--event EVENT", "specify event, ex: 'start'") do |event|
        set_event(event)
      end

      parser.on("-r", "--reason REASON", "specify reason, ex: BUG") do |reason|
        options.reason = reason
      end

      parser.on("-d", "--timestamp TIMESTAMP", "specify timestamp (other than now) to use for event, ex: '2016-04-12 14:01:00'") do |timestamp|
        options.timestamp = timestamp
      end

      parser.on("-s", "--since DATE", "specify a date to use as a start date to retrieve events from, ex: '2016-04-12'") do |since|
        options.since = since
      end

      parser.on("-f", "--find TRACKERID", "specify a story id to search for its events") do |search_id|
        options.search_id = search_id
      end

      parser.on("-k", "--sprint_end DATE", "specify a date to use as a sprint_end date to report on a (2-week) sprint, ex: '2016-04-12'") do |sprint_end|
        options.sprint_end = sprint_end
      end

      parser.on("-z", "--last NUMBER", "specify a number of events (counting backwards in time) to display, ex: 20") do |last|
        options.last = last
      end

      parser.separator ""
      parser.separator "Common options:"

      # This will print an options summary.
      parser.on_tail("-h", "--help", "Show this message") do
        puts parser
        exit
      end
    end
  end

  def no_other_options?
    options.last.nil? && options.since.nil? && options.sprint_end.nil? && options.search_id.nil?
  end

  def get_inputs

    options.event = nil unless EVENTS.keys.map(&:to_s).include?(options.event)
    options.reason = nil unless REASONS.include?(options.reason)

    while !options.last.nil? and !valid_integer?(options.last)
      print "Please supply a valid integer for record retrieval: "
      last = STDIN.gets.chomp
      if valid_integer?(last)
        options.last = last
      end
    end

    while options.tracker_id.nil? && no_other_options?
      print "Please enter story id: "
      tracker_id = STDIN.gets.chomp
      tracker_id[0] = '' if tracker_id[0] == '#'
      if valid_integer?(tracker_id)
        set_tracker_id(tracker_id)
      end
    end

    while options.event.nil? && no_other_options?
      puts
      puts "Event type required."
      puts
      EVENTS.keys.each_with_index do |e, i|
        if event_allowed_next?(e)
          num = i + 1
          puts "#{num}. #{e}"
        end
      end
      puts
      print "Choose an event number: "
      event = STDIN.gets.chomp
      set_event_by_number(event)
    end

    while options.event == 'start' && options.points.nil?
      print "How many points? "
      puts
      points = STDIN.gets.chomp
      if valid_points?(points)
        options.points = points
      end
    end

    if requires_a_reason && options.reason.nil?
      puts "Event requires a reason."
      puts
      while options.reason.nil?
        REASONS.each_with_index do |r, i|
          num = i + 1
          puts "#{num}. #{r}"
        end
        puts
        print "please enter a reason number: "
        reason = STDIN.gets.chomp
        if reason.to_i > 0 && reason.to_i <= REASONS.size
          options.reason = REASONS[reason.to_i - 1]
        end
      end
    end

    if requires_a_reason && options.extended_reason.nil?
      puts "Type additional details or <enter> for none:"
      puts
      options.extended_reason = STDIN.gets.chomp
    end
  end

  def perform_sprint_end
    params = {
      orderBy: '"created_at"',
      startAt: sprint_start_seconds,
      endAt: sprint_end_seconds
    }
    path = rest_request(params)
    events = fetch_events(path)

    finished = events.select {|e| e['event'] == 'finish'}
    uniq_finished = finished.uniq {|e| e['tracker_id'].to_s + e['dev_name'] }
    stories = stories_for(finished_events: uniq_finished)

    reject_event_count = events.count {|e| e['event'] == 'reject'}

    sprint = Sprint.new(stories: stories, reject_event_count: reject_event_count)

    puts
    puts "Events for sprint ending #{options.sprint_end}:"
    puts report_rule
    display_formatted events
    puts
    puts "Finished stories for sprint ending #{options.sprint_end}:"
    puts report_rule
    display_formatted uniq_finished, false
    puts
    puts "Sprint Metrics for sprint ending #{options.sprint_end}:"
    puts report_rule
    puts "Finished Points:    #{sprint.finished_points}"
    puts "Avg Points Per Dev: #{sprint.average_points_per_developer}"
    puts "Avg Cycle Hours:    #{sprint.average_cycle_hours} (#{sprint.average_cycle_days} days)"
    puts "Rejection %:        #{sprint.rejection_percent}"
    puts
  end

  def perform_since
    title = "Here are the events since #{options.since}:"
    start_time = parsed_time(options.since).to_i
    params = {
      orderBy: '"created_at"',
      startAt: start_time
    }
    report_on(title, params)
  end

  def perform_last
    title = "Here are the last #{options.last} events:"
    params = {
      orderBy: '"created_at"',
      limitToLast: options.last
    }
    report_on(title, params)
  end

  # TODO: use already cached fb_events instead of
  # running the same query via report_on
  def perform_id_search
    tracker_id = options.search_id
    title = "Events for story id: #{tracker_id}:"
    tracker_id[0] = '' if tracker_id[0] == '#'
    set_tracker_id(tracker_id)
    params = {
      orderBy: '"tracker_id"',
      equalTo: "\"#{tracker_id}\""
    }
    report_on(title, params)
  end

  def perform_ads_story_action
    if ads_story && options.tracker_id && options.event
      case options.event
      when 'start'
        set_ads_story_points
        ads_story.start
      when 'finish'
        ads_story.finish
      when 'stop'
        ads_story.stop(reason: full_reason)
      when 'block'
        ads_story.block(reason: full_reason)
      when 'resume'
        ads_story.resume
      when 'reject'
        ads_story.reject(reason: full_reason)
      when 'restart'
        ads_story.restart
      else
      end
    end
  end

  def set_ads_story_points
    if options.points && ads_story && ads_story.points.to_s.strip.empty?
      ads_story.set_points(options.points)
    end
  end

  def perform_firebase_action

    if options.tracker_id && options.event
      response = firebase.push( 'events',
        {
          tracker_id:      options.tracker_id,
          points:          options.points,
          dev_name:        dev_name,
          event:           options.event,
          reason:          options.reason,
          extended_reason: options.extended_reason,
          created_at:      parsed_timestamp
        }
      )

      if response.success?
        event_key = JSON.parse(response.raw_body)['name']
        new_event = retrieve_event(event_key)

        puts
        puts "[#{options.event}] event registered for story ##{options.tracker_id} !"
        puts
        puts new_event
        puts

      else
        error_msg = JSON.parse(response.raw_body)['error']
        puts "ERROR occurred while attmpting to save: #{error_msg}"
      end
    elsif !options.last.nil?
      perform_last
    elsif !options.since.nil?
      perform_since
    elsif !options.search_id.nil?
      perform_id_search
    elsif !options.sprint_end.nil?
      perform_sprint_end
    else
      puts "No action: missing required options!"
    end
  end

  def retrieve_event(event_key)
    response = firebase.get("events/#{event_key}")
    if response.success?
      JSON.parse response.raw_body
    else
      "Error: unable to retrieve event."
    end
  rescue
    "Error: unable to retrieve event."
  end

  def dev_name
    local_settings['dev_name']
  end

  def parsed_timestamp
    if options.timestamp
      while !confirm_parsed_time?
        obtain_new_time_from_user
      end
      parsed_time.to_i
    else
      Time.now.to_i
    end
  end

  def parsed_time(str = options.timestamp)
    Time.local(*str.split(/\D/))
  end

  def confirm_parsed_time?
    puts "Is this the time you want (y/n)? #{parsed_time}"
    puts
    answer = STDIN.gets.chomp
    answer == 'y'
  end

  def obtain_new_time_from_user
    puts "Please re-enter time like yyyy-mm-dd hh:mm:ss:"
    puts
    options.timestamp = STDIN.gets.chomp
  end

  def load_local_settings
    raise "you need to run ctf_setup" if `echo $CTF_DIR`.chomp.empty?
    ctf_dir = `echo $CTF_DIR`.chomp
    local_settings_file = "#{ctf_dir}/#{LOCAL_SETTINGS_FILE}"
    raise "you need a '#{local_settings_file}' !" unless File.exists?(local_settings_file)
    YAML.load_file local_settings_file
  end

private

  def event_allowed_next?(event)
    if last_fb_event.nil?
      event == :start ? true : false
    else
      EVENTS[last_fb_event.to_sym][:allowed_next].include?(event)
    end
  end

  def last_fb_event
    if fb_events.empty?
      nil
    else
      fb_events.last["event"]
    end
  end

  def fb_events
    @fb_events ||= all_events_for(tracker_id: options.tracker_id)
  end

  def full_reason
    reason = options.reason
    ext_reason = options.extended_reason.to_s.strip
    if ext_reason.empty?
      reason
    else
      [reason, ext_reason].join(" - ")
    end
  end

  def set_story_points
    if options.event == 'start' && ads_story
      unless ads_story.points.to_s.strip.empty?
        options.points = ads_story.points
      end
    end
  end

  def set_event(event_name)
    if valid_event_name?(event_name)
      options.event = event_name.to_s
      set_story_points
    end
  end

  def set_event_by_number(event_number)
    if valid_event_number?(event_number)
      event_name = EVENTS.keys[event_number.to_i - 1]
      options.event = event_name.to_s
      set_story_points
    end
  end

  def valid_event_name?(event_name)
    EVENTS.keys.map(&:to_s).include?(event_name)
  end

  def valid_event_number?(event)
    event.to_i > 0 && event.to_i <= EVENTS.keys.size
  end

  def set_tracker_id(tracker_id)
    set_ads_story(tracker_id)
    AdsStoryDisplay.new(ads_story).render
    options.tracker_id = tracker_id
    fb_events
  end

  def set_ads_story(id)
    @ads_story = AdsStory.new(id: id)
  rescue => e
    abort(e.message)
  end

  def requires_a_reason
    return false if options.event.nil?
    EVENTS[options.event.to_sym][:requires_a_reason]
  end

  def valid_points?(val)
    Float(val) != nil rescue false
  end

  def valid_integer?(val)
    result = Integer(val) rescue false
    !!result
  end

  def stories_for(finished_events:)
    finished_events.map do |event|
      story_events = all_events_for(tracker_id: event['tracker_id'])
      Story.new(
        events: story_events,
        developer: event['dev_name'],
        sprint_start_seconds: sprint_start_seconds
      )
    end
  end

  def all_events_for(tracker_id:)
    params = {
      orderBy: '"tracker_id"',
      equalTo: "\"#{tracker_id}\""
    }
    path = rest_request(params)
    fetch_events(path)
  end

  def sprint_start_seconds
    parsed_time(options.sprint_end).to_i - sprint_length
  end

  def sprint_end_seconds
    parsed_time(options.sprint_end).to_i
  end

  def report_on(title, params)
    path = rest_request(params)
    events = fetch_events(path)
    puts
    puts title
    puts
    display_formatted(events)
    puts
  end

  def report_rule
    "----------------------------------------------------------------------"
  end

  def display_formatted(events, with_points = true)
    events.each do |event|
      puts event_line(event, with_points)
    end
  end

  def event_line(event, with_points)
    ary = [
      Time.at(event['created_at']).strftime("%a %b %e, %R"),
      event['event'].ljust(8),
      '#' + event['tracker_id'].to_s.ljust(11)
    ]
    ary << point_display_for(event) if with_points
    ary << event['dev_name']
    ary.join(pipe)
  end

  def point_display_for(event)
    unless event['points'].nil?
      ("points: #{event['points']}").ljust(11)
    else
      ''.ljust(11)
    end
  end

  def fetch_events(path)
    events = JSON.parse `curl #{path}`
    events.values.sort_by {|e| e['created_at']}
  rescue => e
    abort("Error fetching events from firebase: #{e.message}")
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

  def firebase_uri
    local_settings['firebase_uri']
  end

  def firebase_secret
    local_settings['firebase_secret']
  end

  def pipe
    ' | '
  end

  def sprint_length
    14 * one_day
  end

  def one_day
    24 * 60 * 60
  end
end

