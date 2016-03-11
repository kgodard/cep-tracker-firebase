#!/usr/bin/env ruby

require 'optparse'
require 'firebase'
require 'json'
require 'yaml'
require 'byebug'

# contains all finished pivotal_stories for a given sprint
class PivotalSprint
  attr_reader :pivotal_stories, :reject_event_count

  def initialize(pivotal_stories: [], reject_event_count: 0)
    @pivotal_stories = pivotal_stories
    @reject_event_count = reject_event_count
  end

  def average_cycle_days
    (average_cycle_hours / 24).round(2)
  end

  def average_cycle_hours
    (story_cycle_hours_sum / story_count).round(2)
  end

  def finished_points
    pivotal_stories.inject(0) do |sum, story|
      sum += story.points
    end
  end

  def rejection_percent
    return 0 if reject_event_count == 0
    ((reject_event_count.to_f / story_count) * 100).round(2)
  end

private

  def story_cycle_hours_sum
    story_cycle_hours_array.inject(0) {|sum, i| sum += i}.to_f
  end

  def story_count
    pivotal_stories.size
  end

  def story_cycle_hours_array
    pivotal_stories.map(&:cycle_hours)
  end
end

# contains all events for a given story
class PivotalStory
  attr_reader :events, :developer, :sprint_start_seconds

  def initialize(events: [], developer: nil, sprint_start_seconds: nil)
    @events, @developer = events, developer
    @sprint_start_seconds = sprint_start_seconds
  end

  def cycle_hours
    cycle_seconds / 3600.0
  end

  def contains_reject?
    events.any? {|e| e['event'] == 'reject' && e['dev_name'] == developer}
  end

  def points
    start_event['points'].to_i rescue 0
  end

private

  def cycle_seconds
    start_to_finish_seconds - blocked_seconds
  end

  def start_event
    detect_event('start')
  end

  def finish_event
    detect_event('finish')
  end

  def detect_event(event_name)
    events.detect {|e| e['event'] == event_name && e['dev_name'] == developer}
  end

  def blocked_seconds
    return 0 unless detect_event('block')
    seconds = 0
    block_seconds = 0
    events.each do |event|
      if event['event'] == 'block'
        block_seconds = event['created_at']
      elsif event['event'] == 'resume'
        seconds += event['created_at'] - block_seconds
      end
    end
    seconds
  end

  def start_to_finish_seconds
    if start_event.nil?
      finish_event['created_at'] - sprint_start_seconds
    else
      finish_event['created_at'] - start_event['created_at']
    end
  end
end

class ScriptOptions
  attr_accessor :tracker_id, :points, :event, :reason,
    :extended_reason, :timestamp, :last, :since, :sprint_end,
    :search_id

  def initialize
    @tracker_id      = nil
    @search_id       = nil
    @points          = nil
    @event           = nil
    @reason          = nil
    @extended_reason = nil
    @timestamp       = nil
    @last            = nil
    @since           = nil
    @sprint_end      = nil
  end
end

class CepTracker

  FIREBASE_URI = 'https://cep-tracker.firebaseIO.com'

  NON_REASON_EVENTS = %w[ start resume finish restart play ]
  REASON_EVENTS = %w[ stop reject block pause ]
  EVENTS = NON_REASON_EVENTS + REASON_EVENTS

  REASONS = %w[ bug cep hardware firmware devops it bad_ac qa priority_change other ].map(&:upcase)

  LOCAL_SETTINGS_FILE = 'my_settings.yml'

  attr_reader :firebase, :options, :parser, :local_settings

  def initialize(args)
    @options        = ScriptOptions.new
    @local_settings = load_local_settings
    @firebase       = Firebase::Client.new(FIREBASE_URI, firebase_secret)
    option_parser.parse!(args)
    get_inputs
    perform_firebase_action
  end

  def option_parser
    @parser ||= OptionParser.new do |parser|
      parser.banner = "Usage: ctf.rb [options]"
      parser.separator ""
      parser.separator "Specific options:"

      # additional options
      parser.on("-t", "--tracker TRACKERID", "specify pivotal tracker story id") do |tracker_id|
        options.tracker_id = tracker_id
      end

      parser.on("-p", "--points POINTS", "specify pivotal tracker story points") do |points|
        options.points = points
      end

      parser.on("-e", "--event EVENT", "specify event, ex: 'start'") do |event|
        options.event = event
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

      parser.on("-f", "--find TRACKERID", "specify a pivotal tracker story id to search for its events") do |search_id|
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

    options.event = nil unless EVENTS.include?(options.event)
    options.reason = nil unless REASONS.include?(options.reason)

    while !options.last.nil? and !valid_integer?(options.last)
      puts "Please supply a valid integer for record retrieval:"
      puts
      last = gets.chomp
      if valid_integer?(last)
        options.last = last
      end
    end

    while options.tracker_id.nil? && no_other_options?
      puts "Please enter pivotal tracker id:"
      puts
      tracker_id = gets.chomp
      tracker_id[0] = '' if tracker_id[0] == '#'
      if valid_integer?(tracker_id)
        options.tracker_id = tracker_id
      end
    end

    while options.event.nil? && no_other_options?
      puts "Event type required."
      puts
      EVENTS.each_with_index do |e, i|
        num = i + 1
        puts "#{num}. #{e}"
      end
      puts "Choose an event number:"
      event = gets.chomp
      if event.to_i > 0 && event.to_i <= EVENTS.size
        options.event = EVENTS[event.to_i - 1]
      end
    end

    while options.event == 'start' && options.points.nil?
      puts "How many points?"
      puts
      points = gets.chomp
      if valid_integer?(points)
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
        puts "please enter a reason number:"
        reason = gets.chomp
        if reason.to_i > 0 && reason.to_i <= REASONS.size
          options.reason = REASONS[reason.to_i - 1]
        end
      end
    end

    if requires_a_reason && options.extended_reason.nil?
      puts "Would you like to elaborate?"
      puts
      options.extended_reason = gets.chomp
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
    pivotal_stories = pivotal_stories_for(finished_events: uniq_finished)

    reject_event_count = events.count {|e| e['event'] == 'reject'}

    sprint = PivotalSprint.new(pivotal_stories: pivotal_stories, reject_event_count: reject_event_count)

    puts
    puts "Events for sprint ending #{options.sprint_end}:"
    puts "-------------------------------------------------------"
    display_formatted events
    puts
    puts "Finished stories for sprint ending #{options.sprint_end}:"
    puts "-------------------------------------------------------"
    display_formatted uniq_finished
    puts
    puts "Sprint Metrics for sprint ending #{options.sprint_end}:"
    puts "-------------------------------------------------------"
    puts "Finished Points:     #{sprint.finished_points}"
    puts "Average Cycle Hours: #{sprint.average_cycle_hours} (#{sprint.average_cycle_days} days)"
    puts "Rejection %:         #{sprint.rejection_percent}"
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

  def perform_id_search
    tracker_id = options.search_id
    title = "Events for pivotal story id: #{tracker_id}:"
    tracker_id[0] = '' if tracker_id[0] == '#'
    params = {
      orderBy: '"tracker_id"',
      equalTo: "\"#{tracker_id}\""
    }
    report_on(title, params)
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
    answer = gets.chomp
    answer == 'y'
  end

  def obtain_new_time_from_user
    puts "Please re-enter time like yyyy-mm-dd hh:mm:ss:"
    puts
    options.timestamp = gets.chomp
  end

  def load_local_settings
    raise "you need to run rake ctf_setup" if `echo $CTF_DIR`.chomp.empty?
    ctf_dir = `echo $CTF_DIR`.chomp
    local_settings_file = "#{ctf_dir}/#{LOCAL_SETTINGS_FILE}"
    raise "you need a '#{local_settings_file}' !" unless File.exists?(local_settings_file)
    YAML.load_file local_settings_file
  end

private

  def requires_a_reason
    REASON_EVENTS.include? options.event
  end

  def valid_integer?(val)
    result = Integer(val) rescue false
    !!result
  end

  def pivotal_stories_for(finished_events:)
    finished_events.map do |event|
      story_events = all_events_for(tracker_id: event['tracker_id'])
      PivotalStory.new(
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

  def display_formatted(events)
    events.each do |e|
      puts [
        Time.at(e['created_at']).strftime("%a %b %e, %R"),
        e['event'].ljust(8),
        '#' + e['tracker_id'].to_s.ljust(11),
        e['dev_name']
      ].join(pipe)
    end
  end

  def fetch_events(path)
    events = JSON.parse `curl #{path}`
    events.values.sort_by {|e| e['created_at']}
  end

  def rest_request(params)
    base = url_with_auth
    params.each do |k,v|
      base += "&#{k}=#{v}"
    end
    base.to_json
  end

  def url_with_auth
    "#{FIREBASE_URI}/events.json?auth=#{firebase_secret}"
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

CepTracker.new(ARGV)
