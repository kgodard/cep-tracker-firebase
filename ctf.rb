#!/usr/bin/env ruby

require 'optparse'
require 'firebase'
require 'json'
require 'yaml'
require 'byebug'
require './sprint.rb'
require './story.rb'
require './script_options.rb'
require './ads_story.rb'
require './ads_story_display.rb'
require './firebase_event.rb'
require './cep_tracker.rb'

CepTracker.new(ARGV)
