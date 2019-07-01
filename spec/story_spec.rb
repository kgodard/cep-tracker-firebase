require_relative '../story.rb'
require_relative '../ads_story.rb'

describe Story do

  let(:day) { 24 * 3600 }
  let(:developer_name) { 'Person' }
  let(:start_points) { "1.1" }

  let(:events) {
    [
      {
        "tracker_id" =>  12345,
        "points" =>      start_points,
        "dev_name" =>    developer_name,
        "event" =>       'start',
        "created_at" =>  (Time.now - 3 * day).to_i
      },
      {
        "tracker_id" =>  12345,
        "points" =>      nil,
        "dev_name" =>    developer_name,
        "event" =>       'finish',
        "created_at" =>  (Time.now - 1 * day).to_i
      }
    ]
  }

  let(:firebase_event) {
    double("firebase_event", search: events)
  }

  let(:ads_story_double) {
    class_double("AdsStory").
      as_stubbed_const(:transfer_nested_constants => true)
  }

  subject {
    Story.new(event: events.last, firebase_event: firebase_event)
  }

  describe "#points" do
    it "returns the points of the start event" do
      expect(ads_story_double).to receive(:new).with(id: events.last["tracker_id"])
      expect(subject.points).to eq start_points.to_f
    end
  end

  describe "#cycle_hours" do
    it "equals 48 hours" do
      expect(ads_story_double).to receive(:new).with(id: events.last["tracker_id"])
      expect(subject.cycle_hours).to eq 48.0
    end
  end

  describe "#contains_reject?" do
    it "is false" do
      expect(ads_story_double).to receive(:new).with(id: events.last["tracker_id"])
      expect(subject.contains_reject?).to be false
    end
  end
end
