class CepTracker

  EVENTS = {
    start: {
      requires_a_reason: false,
      allowed_next: [:accept, :block, :finish, :stop]
    },
    stop: {
      requires_a_reason: true,
      allowed_next: [:resume]
    },
    block: {
      requires_a_reason: true,
      allowed_next: [:resume]
    },
    resume: {
      requires_a_reason: false,
      allowed_next: [:accept, :block, :finish, :stop]
    },
    accept: {
      requires_a_reason: false,
      allowed_next: [:finish, :reject]
    },
    finish: {
      requires_a_reason: false,
      allowed_next: []
    },
    reject: {
      requires_a_reason: true,
      allowed_next: [:restart]
    },
    restart: {
      requires_a_reason: false,
      allowed_next: [:accept, :block, :finish, :stop]
    }
  }

  REASONS = %w[ bug hardware firmware devops it bad_ac qa priority_change other ].map(&:upcase)

  LOCAL_SETTINGS_FILE = 'ctf_settings.yml'

  attr_reader :firebase_event, :options, :parser, :dev_name, :ads_story

  def initialize(args)
    local_settings  = load_local_settings
    @options        = ScriptOptions.new
    @dev_name       = local_settings['dev_name']
    @firebase_event = FirebaseEvent.new(
      firebase_uri:    local_settings['firebase_uri'],
      firebase_secret: local_settings['firebase_secret']
    )
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
      parser.on("-c", "--comment COMMENT", "add a comment to ADS story (no event created), ex: 'I am Groot'") do |comment|
        options.comment = comment
      end

      parser.on("-d", "--timestamp TIMESTAMP", "specify timestamp to use for event, ex: '2016-04-12 14:01:00'") do |timestamp|
        options.timestamp = timestamp
      end

      parser.on("-e", "--event EVENT", "specify event, ex: 'start'") do |event|
        set_event(event)
      end

      parser.on("-f", "--find TRACKERID", "specify a story id to search for its events") do |search_id|
        options.search_id = search_id
      end

      parser.on("-k", "--sprint_end DATE", "specify sprint_end date for 2-week sprint report, ex: '2016-04-12'") do |sprint_end|
        options.sprint_end = sprint_end
      end

      parser.on("-n", "--number_of_sprints NUMBER", "specify number of sprints to report on (requires --sprint_end option), ex: 3") do |number_of_sprints|
        options.number_of_sprints = number_of_sprints.to_i
      end

      parser.on("-o", "--open", "open ADS story in default browser (requires --tracker option)") do
        options.open = true
      end

      parser.on("-p", "--points POINTS", "specify story points") do |points|
        options.points = points
      end

      parser.on("-r", "--reason REASON", "specify reason, ex: BUG") do |reason|
        options.reason = reason
      end

      parser.on("-s", "--since DATE", "specify a since date to retrieve events from, ex: '2016-04-12'") do |since|
        options.since = since
      end

      parser.on("-t", "--tracker TRACKERID", "specify story id") do |tracker_id|
        set_tracker_id(tracker_id)
      end

      parser.on("-x", "--filter FILTER", "filter sprint end results by story attr (requires --sprint_end option), ex: 'area=DemGray'") do |filter|
        options.filter = filter
      end

      parser.on("-z", "--last NUMBER", "specify number of events (counting backwards in time) to display, ex: 20") do |last|
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

  def no_comment?
    options.comment.nil?
  end

  def no_open?
    options.open != true
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

    # reset event if it's not a valid next event
    validate_event

    while options.event.nil? && no_other_options? && no_comment? && no_open?
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
      points = STDIN.gets.chomp
      if valid_points?(points)
        options.points = points
      end
    end

    if requires_a_reason && options.reason.nil?
      puts
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
    increment = Sprint.new(
      sprint_end: options.sprint_end,
      firebase_event: firebase_event,
      filter: options.filter,
      number_of_sprints: options.number_of_sprints
    )
    IncrementDisplay.new(increment: increment).render
  end

  def perform_since
    title = "Here are the events since #{options.since}:"
    start_time = parsed_time(options.since).to_i
    params = {
      orderBy: '"created_at"',
      startAt: start_time
    }
    since_events = fetch_fb_events(params)
    EventDisplay.new(title: title, events: since_events).render
  end

  def perform_last
    title = "Here are the last #{options.last} events:"
    params = {
      orderBy: '"created_at"',
      limitToLast: options.last
    }
    last_events = fetch_fb_events(params)
    EventDisplay.new(title: title, events: last_events).render
  end

  def perform_id_search
    tracker_id = options.search_id
    title = "Events for story id: #{tracker_id}:"
    tracker_id[0] = '' if tracker_id[0] == '#'
    set_tracker_id(tracker_id)
    EventDisplay.new(title: title, events: fb_events).render
  end

  def perform_ads_story_action
    if ads_story && options.tracker_id
      case options.event
      when 'accept'
        ads_story.accept
      when 'block'
        ads_story.block(reason: full_reason)
      when 'finish'
        ads_story.finish
      when 'reject'
        ads_story.reject(reason: full_reason)
      when 'restart'
        ads_story.restart
      when 'resume'
        ads_story.resume
      when 'start'
        set_ads_story_points
        ads_story.start
      when 'stop'
        ads_story.stop(reason: full_reason)
      else
        ads_story.add_comment(options.comment) unless options.comment.nil?
      end
      ads_story.open if options.open
    end
  end

  def set_ads_story_points
    if options.points && ads_story && ads_story.points.to_s.strip.empty?
      ads_story.set_points(options.points)
    end
  end

  def perform_firebase_action
    # create
    if options.tracker_id && options.event
      response = firebase_event.create(params:
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
        # fetch
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
    elsif options.tracker_id && !options.comment.to_s.empty?
      puts
      puts "Added comment to ADS story ##{options.tracker_id}"
      puts
    elsif options.tracker_id && options.open
    else
      puts "No action: missing required options!"
    end
  end

  def retrieve_event(event_key)
    response = firebase_event.fetch(event_key: event_key)
    if response.success?
      JSON.parse response.raw_body
    else
      "Error: unable to retrieve event."
    end
  rescue
    "Error: unable to retrieve event."
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

  def validate_event
    return if options.event.nil?
    if event_allowed_next?(options.event)
      true
    else
      invalid_event_message
      options.event = nil
      false
    end
  end

  def invalid_event_message
    puts
    if last_fb_event.nil?
      puts " !! You must register a [start] event for this story."
    else
      puts " !! Sorry, [#{options.event}] is not a valid event following a [#{last_fb_event}] event."
    end
  end

  def event_allowed_next?(event)
    if last_fb_event.nil?
      event.to_sym == :start ? true : false
    else
      EVENTS[last_fb_event.to_sym][:allowed_next].include?(event.to_sym)
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
    if options.event == 'start'
      if ads_story && !ads_story.points.to_s.strip.empty?
        options.points = ads_story.points
      end
    else
      options.points = nil
    end
  end

  def set_event(event_name)
    if valid_event_name?(event_name)
      options.event = event_name.to_s
      if validate_event
        set_story_points
      end
    end
  end

  def set_event_by_number(event_number)
    if valid_event_number?(event_number)
      event_name = EVENTS.keys[event_number.to_i - 1]
      set_event(event_name)
    end
  end

  def valid_event_name?(event_name)
    EVENTS.keys.map(&:to_s).include?(event_name.to_s)
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

  def all_events_for(tracker_id:)
    params = {
      orderBy: '"tracker_id"',
      equalTo: "\"#{tracker_id}\""
    }
    fetch_fb_events(params)
  end

  def fetch_fb_events(params)
    firebase_event.search(params: params)
  end
end

