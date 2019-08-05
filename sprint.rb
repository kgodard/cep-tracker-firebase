# contains all finished stories for a given sprint
class Sprint
  attr_reader :sprint_end, :firebase_event, :sprint_events,
    :uniq_finished_events, :stories, :rejected_event_count,
    :filters, :number_of_sprints, :dev_count

  def initialize(sprint_end:, firebase_event:, filter: nil, number_of_sprints: 1)
    @sprint_end           = sprint_end
    @firebase_event       = firebase_event
    @filters              = parse_story_filters(filter)
    @number_of_sprints    = number_of_sprints
    @sprint_events        = fetch_sprint_events
    @uniq_finished_events = get_uniq_finished_events
    @stories              = get_stories_for_finished_events
    @dev_count            = developer_count
    @rejected_event_count = count_rejected_events
  end

  def average_team_velocity
    (finished_points / number_of_sprints).round(2)
  end

  def average_cycle_days
    (average_cycle_hours / 24).round(2)
  end

  def average_cycle_hours
    (story_cycle_hours_sum / story_count).round(2)
  end

  def finished_points
    stories.inject(0.0) do |sum, story|
      sum += story.points.to_f
    end.round(2)
  end

  def rejection_percent
    return 0 if rejected_event_count == 0
    ((rejected_event_count.to_f / story_count) * 100).round(2)
  end

  def average_points_per_developer
    (finished_points / dev_count).round(2)
  end

private

  def parsed_time(str)
    Time.local(*str.split(/\D/))
  end

  def count_rejected_events
    sprint_events.count {|e| e['event'] == 'reject'}
  end

  def get_stories_for_finished_events
    unfiltered_stories = uniq_finished_events.map do |event|
      Story.new(
        event: event,
        firebase_event: firebase_event,
        sprint_start_seconds: sprint_start_seconds
      )
    end.reject do |story|
      story.type == "Production Support Incident"
    end
    filter_stories(unfiltered_stories)
  end

  def filter_stories(unfiltered_stories)
    unfiltered_stories.reject do |story|
      filter_story?(story)
    end
  end

  def filter_story?(story)
    filters.each do |filter|
      return true if story.send(filter.first) == filter.last
    end
    false
  end

  def parse_story_filters(str)
    filters = []
    return [] if str.nil?
    str.split(/,/).each do |f|
      k,v = f.split(/=/)
      filters << [ k.to_sym, v ]
    end
    filters
  end

  def get_uniq_finished_events
    finished = sprint_events.select {|e| e['event'] == 'finish'}
    finished.uniq {|e| e['tracker_id'].to_s + e['dev_name'] }
  end

  def fetch_sprint_events
    firebase_event.search(params: event_fetch_params)
  end

  def one_day
    24 * 60 * 60
  end

  def sprint_length
    number_of_sprints * 14 * one_day
  end

  def sprint_start_seconds
    parsed_time(sprint_end).to_i - sprint_length
  end

  def sprint_end_seconds
    parsed_time(sprint_end).to_i
  end

  def event_fetch_params
    {
      orderBy: '"created_at"',
      startAt: sprint_start_seconds,
      endAt: sprint_end_seconds
    }
  end

  def developer_count
    stories.map(&:developer).uniq.count
  end

  def story_cycle_hours_sum
    story_cycle_hours_array.inject(0) {|sum, i| sum += i}.to_f
  end

  def story_count
    stories.size
  end

  def story_cycle_hours_array
    stories.map(&:cycle_hours)
  end
end

