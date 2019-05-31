# Class to represent an ADS story
# https://docs.microsoft.com/en-us/cli/azure/ext/azure-devops/boards/work-item?view=azure-cli-latest#ext-azure-devops-az-boards-work-item-update

require 'json'
require 'byebug'

class AdsStory

  # tags
  STOPPED = 'Stopped'
  BLOCKED = 'Blocked'
  # states
  RESET = 'New'
  STARTED = 'Active'
  FINISHED = 'Resolved'

  attr_reader :id, :url, :area, :iteration, :state, :type, :title,
    :points, :column, :tags, :history, :description

  def initialize(id:)
    @id = id
    fetch_and_load
  end

  def set_title(title)
    update({title: title})
  end

  def set_description(description)
    update({description: description})
  end

  def add_to_description(words)
    desc = description + " #{words}"
    set_description(desc)
  end

  def start
    update({state: STARTED})
  end

  def reset
    update({state: RESET})
  end

  def finish
    update({state: FINISHED})
  end

  def stop(reason: nil)
    add_tag(STOPPED)
    add_comment(reason) if reason
  end

  def block(reason: nil)
    add_tag(BLOCKED)
    add_comment(reason) if reason
  end

  def resume(reason: nil)
    remove_tag(BLOCKED) if blocked?
    remove_tag(STOPPED) if stopped?
    add_comment(reason) if reason
  end

  def stopped?
    has_tag?(STOPPED)
  end

  def blocked?
    has_tag?(BLOCKED)
  end

  def has_tag?(tag)
    !!(tags =~ Regexp.new(tag))
  end

  def add_comment(comment)
    update({discussion: comment})
  end

  def add_tag(tag)
    fields = {tags: append_tag(tag)}
    update_fields(fields)
  end

  def remove_tag(tag)
    patt = Regexp.new("\s?#{tag};?")
    newtags = tags.sub(patt, '')
    update_fields({tags: newtags})
  end

  def attributes
    self.instance_variables.each_with_object({}) do |meth, hsh|
      meth = meth.to_s.gsub(/@/,'').to_sym
      hsh[meth] = self.send(meth)
    end
  end

  def update_fields(args = {})
    az_update_fields(args)
    fetch_and_load
  end

  def update(args = {})
    az_update(args)
    fetch_and_load
  end

  def open
    `az boards work-item show --id #{id} --open`
    return true
  end

private

  def fetch_and_load
    load_story(az_fetch)
  end

  def append_tag(tag)
    tags.to_s + "; #{tag}"
  end

  def load_story(json)
    az_story = json
    @url         = az_story["url"]
    @area        = az_story["fields"]["System.AreaLevel3"]
    @iteration   = az_story["fields"]["System.IterationLevel3"]
    @state       = az_story["fields"]["System.State"]
    @type        = az_story["fields"]["System.WorkItemType"]
    @title       = az_story["fields"]["System.Title"]
    @points      = az_story["fields"]["Microsoft.VSTS.Scheduling.StoryPoints"]
    @column      = az_story["fields"]["System.BoardColumn"]
    @tags        = az_story["fields"]["System.Tags"]
    @history     = az_story["fields"]["System.History"]
    @description = az_story["fields"]["System.Description"]
    return true
  end

  def az_update_fields(args = {})
    unless args.empty?
      params = args.each_with_object([]) do |(k,v), arr|
        arr << "#{k}=\"#{v}\""
      end.join(" ")
      result = `az boards work-item update --id #{id} --fields #{params}`
      JSON.parse(result)
    else
      {}
    end
  end

  def az_update(args = {})
    unless args.empty?
      key = args.keys.first.to_s
      val = args.values.first.to_s
      result = `az boards work-item update --id #{id} --#{key} "#{val}"`
      JSON.parse(result)
    else
      {}
    end
  end

  def az_fetch
   response = `az boards work-item show --id #{id}` 
   JSON.parse(response)
  end

end