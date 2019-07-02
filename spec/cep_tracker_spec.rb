require 'optparse'
require 'firebase'
require 'json'
require 'yaml'
require 'byebug'
require_relative '../sprint.rb'
require_relative '../story.rb'
require_relative '../script_options.rb'
require_relative '../ads_story.rb'
require_relative '../ads_story_display.rb'
require_relative '../firebase_event.rb'
require_relative '../event_display.rb'
require_relative '../sprint_display.rb'
require_relative '../cep_tracker.rb'

describe CepTracker do
  let(:dev_name)        { "Person" }
  let(:firebase_uri)    {"https://abcdef.edu"}
  let(:firebase_secret) {"seekrit"}
  let(:local_settings)  {
    {
      "dev_name"=>dev_name,
      "firebase_uri"=>firebase_uri,
      "firebase_secret"=> firebase_secret
    }
  }

  let(:story_id) { "1234567" }
  let(:story_points) { 1.1 }

  let(:ads_story_double) {
    double("ads_story",
           type: "Double",
           id: story_id,
           title: "Double",
           tags: "Tags",
           state: "New",
           points: story_points
          )
  }

  before do
    allow_any_instance_of(CepTracker).to receive(:load_local_settings).and_return(local_settings)
    allow_any_instance_of(CepTracker).to receive(:perform_ads_story_action)
    allow_any_instance_of(CepTracker).to receive(:perform_firebase_action)
    allow(AdsStory).to receive(:new).with(id: story_id).and_return(ads_story_double)
  end

  subject { CepTracker.new(args) }

  describe "registering events" do
    let(:args) { ["-t", story_id, "-e", event_name] }

    before do
      allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([])
    end

    describe "first event" do
      let(:event_name) { 'finish' }

      it "must be 'start'" do
        allow(STDIN).to receive(:gets).and_return(double("stdin", chomp: 1))
        expect { subject }.to output(/must register a \[start\] event/).to_stdout
      end
    end

    describe "start event" do
      let(:event_name) { 'start' }

      it "sets event points to ads_story points" do
        expect(subject.options.points).to eq story_points
      end
    end
  end
end
