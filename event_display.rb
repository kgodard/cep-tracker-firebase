class EventDisplay
  attr_reader :title, :events, :with_points

  def initialize(title: nil, events:, with_points: true)
    @title  = title
    @events = events
    @with_points = with_points
  end

  def call
    if title
      puts
      puts report_title
      puts
    end
    display_formatted
    puts if title
  end

  private

  def report_title
    if events.empty?
      "No events found."
    else
      title
    end
  end

  def display_formatted
    events.each do |event|
      puts event_line(event)
    end
  end

  def event_line(event)
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

  def pipe
    ' | '
  end
end
