class IncrementDisplay
  attr_reader :increment

  def initialize(increment:)
    @increment = increment
  end

  def render
    story_title
    display_stories
    metrics_title
    display_metrics
  end

  private

  def display_metrics
    exclusions_line
    puts "Finished Points:        #{increment.finished_points}"
    sprints_line
    team_velocity_line
    puts "Contributing Devs:      #{increment.dev_count}"
    puts "Avg Points Per Dev:     #{increment.average_points_per_developer}"
    puts "Avg Cycle Hours:        #{increment.average_cycle_hours} (#{increment.average_cycle_days} days)"
    puts "Rejection %:            #{increment.rejection_percent}"
    puts
  end

  def team_velocity_line
    unless single_sprint?
      puts "Avg Team Velocity:      #{increment.average_team_velocity}"
    end
  end

  def exclusions_line
    unless increment.filters.empty?
      puts "Exclusions:             #{filter_list}"
    end
  end

  def single_sprint?
    increment.number_of_sprints == 1
  end

  def sprints_line
    unless single_sprint?
      puts "Number of Sprints:      #{increment.number_of_sprints}"
    end
  end

  def metrics_title
    puts
    puts "Metrics for #{increment_name} ending #{increment.sprint_end}:"
    report_rule
  end

  def story_title
    puts
    puts "Finished stories for #{increment_name} ending #{increment.sprint_end}:"
  end

  def increment_name
    single_sprint? ? "sprint" : "period"
  end

  def filter_list
    increment.filters.map(&:last).uniq.join(", ")
  end

  def display_stories
    increment.stories.each do |story|
      report_rule
      puts "##{story.tracker_id.ljust(9)} | #{trunc(story.title, 64)}"
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
