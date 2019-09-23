# contains all events for a given story
class Story
  attr_reader :tracker_id, :events, :developer, :sprint_start_seconds, :ads_story, :firebase_event

  def initialize(event:, firebase_event:, sprint_start_seconds: nil)
    @tracker_id           = event['tracker_id']
    @developer            = event['dev_name']
    @sprint_start_seconds = sprint_start_seconds
    @firebase_event       = firebase_event
    @events               = get_story_events
    set_ads_story
  end

  def cycle_hours
    cycle_seconds / 3600.0
  end

  def contains_reject?
    events.any? {|e| e['event'] == 'reject' && e['dev_name'] == developer}
  end

  def points
    start_event['points'].to_f rescue 0.0
  end

  %w[ type title area iteration ].each do | method_name |
    define_method(method_name) do
      ads_story.send method_name.to_sym
    end
  end

private

  def get_story_events
    params = {
      orderBy: '"tracker_id"',
      equalTo: "\"#{tracker_id}\""
    }
    firebase_event.search(params: params)
  end

  def set_ads_story
    @ads_story = AdsStory.new(id: tracker_id)
  rescue => e
    abort(e.message)
  end

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
    events.detect {|e| e['event'] == event_name && e['tracker_id'] == tracker_id}
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

