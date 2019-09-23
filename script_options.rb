class ScriptOptions
  attr_accessor :tracker_id, :points, :event, :reason,
    :extended_reason, :timestamp, :last, :since, :sprint_end,
    :search_id, :comment, :open, :filter, :number_of_sprints,
    :inclusions

  def initialize
    @tracker_id        = nil
    @search_id         = nil
    @points            = nil
    @event             = nil
    @reason            = nil
    @extended_reason   = nil
    @timestamp         = nil
    @last              = nil
    @since             = nil
    @sprint_end        = nil
    @comment           = nil
    @open              = nil
    @filter            = nil
    @inclusions        = nil
    @number_of_sprints = 1
  end
end

