class AdsStoryDisplay
  attr_reader :ads_story

  def initialize(ads_story)
    @ads_story = ads_story
  end

  def render
    puts
    puts rule
    puts "#{ads_story.type}"
    puts rule
    puts "[#{ads_story.id}] #{ads_story.title}"
    puts rule
    puts "Tags: #{ads_story.tags}"
    puts rule
    puts "State: #{ads_story.state} | Points: #{ads_story.points}"
    puts rule
    puts
  end

  private

  def rule
    "----------------------------------------------------------------------"
  end
end
