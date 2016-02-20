#!/usr/bin/env ruby

require 'optparse'
require 'firebase'
require 'json'

class ScriptOptions
  attr_accessor :tracker_id, :event, :reason, :extended_reason, :timestamp

  def initialize
    self.tracker_id = nil
    self.event = nil
    self.reason = nil
    self.extended_reason = nil
    self.timestamp = nil
  end
end

class CepTracker

  FIREBASE_URI = 'https://cep-tracker.firebaseIO.com'

  NON_REASON_EVENTS = %w[ start resume finish restart play ]
  REASON_EVENTS = %w[ stop reject block pause ]
  EVENTS = NON_REASON_EVENTS + REASON_EVENTS

  REASONS = %w[ cep hardware firmware devops it bad_ac qa priority_change other ].map(&:upcase)

  attr_reader :firebase, :options, :parser

  def initialize(args)
    @options = ScriptOptions.new
    @firebase = Firebase::Client.new(FIREBASE_URI)
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

      parser.on("-e", "--event EVENT", "specify event, ex: 'start'") do |event|
        options.event = event
      end

      parser.on("-r", "--reason REASON", "specify reason, ex: cep") do |reason|
        options.reason = reason
      end

      parser.on("-d", "--timestamp TIMESTAMP", "specify timestamp to user for event, ex: 2016-04-12 14:01:00") do |timestamp|
        options.timestamp = timestamp
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

  def get_inputs

    options.event = nil unless EVENTS.include?(options.event)
    options.reason = nil unless REASONS.include?(options.reason)

    while options.tracker_id.nil?
      puts "Please enter pivotal tracker id (no #):"
      puts
      tracker_id = gets.chomp
      if valid_integer?(tracker_id)
        options.tracker_id = tracker_id
      end
    end

    while options.event.nil?
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

    if REASON_EVENTS.include? options.event
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

    if options.reason == 'OTHER' && options.extended_reason.nil?
      puts "Would you like to elaborate?"
      puts
      options.extended_reason = gets.chomp
    end

  end

  def valid_integer?(val)
    result = Integer(val) rescue false
    !!result
  end

  def perform_firebase_action
    if options.tracker_id && options.event
      response = firebase.push( 'events',
        {
          tracker_id:      options.tracker_id,
          event:           options.event,
          reason:          options.reason,
          extended_reason: options.extended_reason,
          created_at:      parsed_timestamp
        }
      )

      if response.success?

        puts
        puts "[#{options.event}] event registered for story ##{options.tracker_id} !"
        puts
        puts JSON.parse response.raw_body
        puts

      else
        puts "ERROR occurred while attmpting to save!"
      end
    else
      puts "No action: missing required options!"
    end
  end

  def parsed_timestamp
    if options.timestamp
      Time.parse(options.timestamp).to_i
    else
      Time.now.to_i
    end
  end
end

CepTracker.new(ARGV)
