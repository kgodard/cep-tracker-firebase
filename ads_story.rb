# Class to represent an ADS story
# https://docs.microsoft.com/en-us/cli/azure/ext/azure-devops/boards/work-item?view=azure-cli-latest#ext-azure-devops-az-boards-work-item-update

require 'json'
require 'byebug'

class AdsStory

  DEFAULT_TARGETED_PROJECT = 'Backlog'
  BUG_TYPE = 'Bug'

  # tags
  DEMO_MINS_PREFIX = 'demo-mins:'
  STOPPED = 'Stopped'
  BLOCKED = 'Blocked'
  REJECTED = 'Rejected'
  QA_READY = 'QA ready'
  QA_COMPLETE = 'QA complete'
  DEMO_ACCEPTED = 'Demo accepted'
  # states
  RESET = 'New'
  STARTED = 'Active'
  ACCEPTED = 'Resolved'
  FINISHED = 'Closed'

  attr_reader :id, :url, :area, :iteration, :state, :type, :title,
    :points, :column, :tags, :history, :description, :targeted_project

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
    update({state: STARTED}) unless state == STARTED
  end

  def restart
    remove_tag(REJECTED) if rejected?
    start
  end

  def reset
    remove_tag(QA_READY)
    remove_tag(QA_COMPLETE)
    remove_tag(DEMO_ACCEPTED)
    remove_demo_mins_tag
    update({state: RESET}) unless state == RESET
  end

  def reject(reason: '')
    start
    remove_tag(QA_READY)
    remove_tag(QA_COMPLETE)
    remove_demo_mins_tag
    add_tag(REJECTED) unless rejected?
    add_comment(reason)
  end

  def qa_ready
    add_tag(QA_READY) unless qa_ready?
    update({state: STARTED}) unless state == STARTED
  end

  def qa_complete(demo_mins:)
    remove_tag(QA_READY)
    add_tag(QA_COMPLETE) unless qa_complete?
    add_demo_mins_tag(demo_mins)
    update({state: ACCEPTED}) unless state == ACCEPTED
  end

  def add_demo_mins_tag(mins = 0)
    demo_mins_tag = "#{DEMO_MINS_PREFIX}#{mins}"
    add_tag(demo_mins_tag) unless has_tag?(demo_mins_tag)
  end

  def finish
    add_tag(DEMO_ACCEPTED) unless demo_accepted?
    update({state: FINISHED}) unless state == FINISHED
  end

  def stop(reason: '')
    add_tag(STOPPED) unless stopped?
    add_comment(reason)
  end

  def block(reason: '')
    add_tag(BLOCKED) unless blocked?
    add_comment(reason)
  end

  def resume
    remove_tag(BLOCKED) if blocked?
    remove_tag(STOPPED) if stopped?
  end

  def demo_accepted?
    has_tag?(DEMO_ACCEPTED)
  end

  def qa_complete?
    has_tag?(QA_COMPLETE)
  end

  def qa_ready?
    has_tag?(QA_READY)
  end

  def rejected?
    has_tag?(REJECTED)
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
    comment = comment.to_s.strip
    unless comment.empty?
      update({discussion: comment})
    end
  end

  def set_points(points)
    fields = {"Microsoft.VSTS.Scheduling.StoryPoints": points}
    update_fields(fields)
  end

  def add_tag(tag)
    fields = {tags: append_tag(tag)}
    update_fields(fields)
  end

  def remove_demo_mins_tag
    patt = DEMO_MINS_PREFIX + '\d+'
    remove_tag(patt)
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
    set_targeted_project_if_needed
    az_update(args)
    fetch_and_load
  end

  def open
    `az boards work-item show --id #{id} --open`
    return true
  end

  def bug?
    type == BUG_TYPE
  end

private

  def set_targeted_project_if_needed
    set_default_targeted_project if should_set_targeted_project?
  end

  def should_set_targeted_project?
    bug? && has_no_targeted_project?
  end

  def has_no_targeted_project?
    targeted_project.strip.empty?
  end

  def set_default_targeted_project
    update_fields({"Custom.TargetedProject" => DEFAULT_TARGETED_PROJECT})
  end

  def fetch_and_load
    load_story(az_fetch)
  end

  def append_tag(tag)
    tags.to_s + "; #{tag}"
  end

  def load_story(az_story)
    if az_story.empty?
      raise "ADS story #{id} was not found!"
    else
      @url              = az_story["url"] || ""
      @area             = az_story["fields"]["System.AreaLevel3"] || ""
      @iteration        = az_story["fields"]["System.IterationLevel3"] || ""
      @state            = az_story["fields"]["System.State"] || ""
      @type             = az_story["fields"]["System.WorkItemType"] || ""
      @title            = az_story["fields"]["System.Title"] || ""
      @points           = az_story["fields"]["Microsoft.VSTS.Scheduling.StoryPoints"] || ""
      @column           = az_story["fields"]["System.BoardColumn"] || ""
      @tags             = az_story["fields"]["System.Tags"] || ""
      @history          = az_story["fields"]["System.History"] || ""
      @description      = az_story["fields"]["System.Description"] || ""
      @targeted_project = az_story["fields"]["Custom.TargetedProject"] || ""
      return true
    end
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
   JSON.parse(response) rescue {}
  end
end
