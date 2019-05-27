# contains all finished stories for a given sprint
class Sprint
  attr_reader :stories, :reject_event_count

  def initialize(stories: [], reject_event_count: 0)
    @stories = stories
    @reject_event_count = reject_event_count
  end

  def average_cycle_days
    (average_cycle_hours / 24).round(2)
  end

  def average_cycle_hours
    (story_cycle_hours_sum / story_count).round(2)
  end

  def finished_points
    stories.inject(0) do |sum, story|
      sum += story.points
    end
  end

  def rejection_percent
    return 0 if reject_event_count == 0
    ((reject_event_count.to_f / story_count) * 100).round(2)
  end

  def average_points_per_developer
    (finished_points * 1.0 / developer_count).round(2)
  end

private

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

