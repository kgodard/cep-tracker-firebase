# contains all events for a given story
class Story
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

