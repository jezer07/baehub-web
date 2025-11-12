require "delegate"

# Lightweight wrapper used to represent a specific instance of an Event,
# particularly when expanding recurring events into per-occurrence records.
class EventOccurrence < SimpleDelegator
  attr_reader :occurrence_starts_at, :occurrence_ends_at

  def self.model_name
    Event.model_name
  end

  def initialize(event, starts_at:, ends_at:)
    super(event)
    @occurrence_starts_at = starts_at
    @occurrence_ends_at = ends_at
  end

  def starts_at
    occurrence_starts_at || super
  end

  def ends_at
    occurrence_ends_at || super
  end

  def occurrence?
    true
  end

  def base_event
    __getobj__
  end
end
