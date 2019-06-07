class SprintDisplay
  attr_reader :sprint, :sprint_events, :uniq_finished_events, :sprint_end

  def initialize(sprint:)
    @sprint               = sprint
    @sprint_events        = sprint.sprint_events
    @uniq_finished_events = sprint.uniq_finished_events
    @sprint_end           = sprint.sprint_end
  end

  def render
    puts
    puts "Events for sprint ending #{sprint_end}:"
    report_rule
    EventDisplay.new(events: sprint_events).render
    puts
    puts "Finished stories for sprint ending #{sprint_end}:"
    display_stories
    puts
    puts "Sprint Metrics for sprint ending #{sprint_end}:"
    report_rule
    puts "Finished Points:    #{sprint.finished_points}"
    puts "Avg Points Per Dev: #{sprint.average_points_per_developer}"
    puts "Avg Cycle Hours:    #{sprint.average_cycle_hours} (#{sprint.average_cycle_days} days)"
    puts "Rejection %:        #{sprint.rejection_percent}"
    puts
  end

  private

  def display_stories
    sprint.stories.each do |story|
      report_rule
      puts "##{story.tracker_id.ljust(9)} | #{trunc(story.title, 65)}"
      puts "#{story.type.ljust(10)} | #{story.area.ljust(9)} | #{story.iteration.ljust(11)}" +
        "| #{story.developer.ljust(16)} | %2.2f" % story.points
    end
    report_rule
  end

  def trunc(txt, chars)
    dotdot = txt.length > chars ? '...' : ''
    txt[0,chars] + dotdot
  end

  def report_rule
    puts "--------------------------------------------------------------------------------"
  end
end
