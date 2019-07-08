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
  let(:day) { 24 * 3600 }
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
  let(:story_title) { "Double" }
  let(:fb_event_name) { 'start' }

  let(:ads_story_double) {
    double("ads_story",
           type: "Double",
           id: story_id,
           title: story_title,
           tags: "Tags",
           state: "New",
           points: story_points
          )
  }

  let(:fb_event) {
    {
      "tracker_id" =>  story_id,
      "points" =>      story_points,
      "dev_name" =>    dev_name,
      "event" =>       fb_event_name,
      "created_at" =>  (Time.now - 3 * day).to_i
    }
  }

  before do
    allow_any_instance_of(CepTracker).to receive(:load_local_settings).and_return(local_settings)
    allow(AdsStory).to receive(:new).with(id: story_id).and_return(ads_story_double)
  end

  subject { CepTracker.new(args) }

  describe "-o (open)" do
    before do
      allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([])
      expect(ads_story_double).to receive(:open).and_return(true)
    end

    context "with tracker id provided" do
      let(:args) { ["-o", "-t", story_id] }

      it "sends 'open' to ads_story" do
        expect { subject }.to output(/#{story_title}/).to_stdout
      end
    end

    context "without tracker id" do
      let(:args) { ["-o"] }

      it "prompts for id and sends 'open' to ads_story" do
        allow(STDIN).to receive(:gets).and_return(double("stdin", chomp: story_id))
        expect { subject }.to output(/#{story_title}/).to_stdout
      end
    end
  end

  describe "-c (comment)" do
    let(:comment) { "my comment" }

    before do
      allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([])
      expect(ads_story_double).to receive(:add_comment).with(comment)
    end

    context "with tracker id provided" do
      let(:args) { ["-c", comment, "-t", story_id] }

      it "sends comment to ads_story" do
        expect { subject }.to output(/Added comment/).to_stdout
      end
    end

    context "without tracker id" do
      let(:args) { ["-c", comment] }

      it "prompts for id and sends comment to ads_story" do
        allow(STDIN).to receive(:gets).and_return(double("stdin", chomp: story_id))
        expect { subject }.to output(/Added comment/).to_stdout
      end
    end
  end

  describe "-z (last n events)" do
    let(:num_of_events) { "5" }
    let(:args) { ["-z", num_of_events] }

    before do
      allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([fb_event])
    end

    it "outputs the correct title" do
      expect { subject }.to output(/Here are the last #{num_of_events} events/).to_stdout
    end

    it "outputs the one event" do
      expect { subject }.to output(/#{story_id}/).to_stdout
    end

    context "with no events" do
      before do
        allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([])
      end

      it "outputs no events" do
        expect { subject }.to_not output(/#{story_id}/).to_stdout
      end
    end
  end

  describe "-s (since)" do
    let(:since_date) { Time.at(Time.now - 4 * day).strftime("%Y-%m-%d") }
    let(:args) { ["-s", since_date] }

    before do
      allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([fb_event])
    end

    it "outputs the correct title" do
      expect { subject }.to output(/Here are the events since #{since_date}/).to_stdout
    end

    it "outputs the one event" do
      expect { subject }.to output(/#{story_id}/).to_stdout
    end

    context "with no events" do
      before do
        allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([])
      end

      it "outputs no events" do
        expect { subject }.to_not output(/#{story_id}/).to_stdout
      end
    end
  end

  describe "-f (find)" do
    let(:args) { ["-f", story_id] }

    before do
      allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([fb_event])
    end

    it "outputs existing ads story" do
      expect { subject }.to output(/#{story_title}/).to_stdout
    end

    it "outputs existing firebase events" do
      expect { subject }.to output(/Events for story id: #{story_id}/).to_stdout
    end
  end

  describe "registering events" do
    let(:args) { ["-t", story_id, "-e", event_name] }

    before do
      allow_any_instance_of(CepTracker).to receive(:perform_firebase_action)
      allow_any_instance_of(CepTracker).to receive(:perform_ads_story_action)
    end

    describe "when no previous events exist" do
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

  describe "next events" do
    let(:args) { ["-t", story_id, "-e", event_name] }

    before do
      allow_any_instance_of(FirebaseEvent).to receive(:search).and_return([fb_event])
      allow_any_instance_of(CepTracker).to receive(:perform_firebase_action)
      allow_any_instance_of(CepTracker).to receive(:perform_ads_story_action)
      allow(STDIN).to receive(:gets).and_return(double("stdin", chomp: prompt_number))
    end

    shared_examples "allowed" do |event_name|
      let(:event_name) { event_name }
      specify { expect { subject }.to_not output(/Event type required/).to_stdout }
    end

    shared_examples "NOT allowed" do |event_name|
      let(:event_name) { event_name }
      specify { expect { subject }.to output(/not a valid event/).to_stdout }
    end

    context "after 'start'" do
      let(:prompt_number) { 2 }

      describe "allowed events" do
        it_behaves_like "allowed", "finish"
        it_behaves_like "allowed", "stop"
        it_behaves_like "allowed", "block"
      end

      describe "NOT allowed events" do
        it_behaves_like "NOT allowed", "start"
        it_behaves_like "NOT allowed", "resume"
        it_behaves_like "NOT allowed", "restart"
        it_behaves_like "NOT allowed", "reject"
      end
    end

    context "after 'finish'" do
      let(:fb_event_name) { 'finish' }
      let(:prompt_number) { 7 }

      describe "allowed events" do
        it_behaves_like "allowed", "reject"
      end

      describe "NOT allowed events" do
        it_behaves_like "NOT allowed", "start"
        it_behaves_like "NOT allowed", "resume"
        it_behaves_like "NOT allowed", "restart"
        it_behaves_like "NOT allowed", "stop"
        it_behaves_like "NOT allowed", "block"
        it_behaves_like "NOT allowed", "finish"
      end
    end

    context "after 'resume'" do
      let(:fb_event_name) { 'resume' }
      let(:prompt_number) { 2 }

      describe "allowed events" do
        it_behaves_like "allowed", "finish"
        it_behaves_like "allowed", "stop"
        it_behaves_like "allowed", "block"
      end

      describe "NOT allowed events" do
        it_behaves_like "NOT allowed", "start"
        it_behaves_like "NOT allowed", "resume"
        it_behaves_like "NOT allowed", "restart"
        it_behaves_like "NOT allowed", "reject"
      end
    end

    context "after 'restart'" do
      let(:fb_event_name) { 'restart' }
      let(:prompt_number) { 2 }

      describe "allowed events" do
        it_behaves_like "allowed", "finish"
        it_behaves_like "allowed", "stop"
        it_behaves_like "allowed", "block"
      end

      describe "NOT allowed events" do
        it_behaves_like "NOT allowed", "start"
        it_behaves_like "NOT allowed", "resume"
        it_behaves_like "NOT allowed", "restart"
        it_behaves_like "NOT allowed", "reject"
      end
    end

    context "after 'stop'" do
      let(:fb_event_name) { 'stop' }
      let(:prompt_number) { 3 }

      describe "allowed events" do
        it_behaves_like "allowed", "resume"
      end

      describe "NOT allowed events" do
        it_behaves_like "NOT allowed", "start"
        it_behaves_like "NOT allowed", "reject"
        it_behaves_like "NOT allowed", "restart"
        it_behaves_like "NOT allowed", "stop"
        it_behaves_like "NOT allowed", "block"
        it_behaves_like "NOT allowed", "finish"
      end
    end

    context "after 'block'" do
      let(:fb_event_name) { 'block' }
      let(:prompt_number) { 3 }

      describe "allowed events" do
        it_behaves_like "allowed", "resume"
      end

      describe "NOT allowed events" do
        it_behaves_like "NOT allowed", "start"
        it_behaves_like "NOT allowed", "reject"
        it_behaves_like "NOT allowed", "restart"
        it_behaves_like "NOT allowed", "stop"
        it_behaves_like "NOT allowed", "block"
        it_behaves_like "NOT allowed", "finish"
      end
    end

    context "after 'reject'" do
      let(:fb_event_name) { 'reject' }
      let(:prompt_number) { 4 }

      describe "allowed events" do
        it_behaves_like "allowed", "restart"
      end

      describe "NOT allowed events" do
        it_behaves_like "NOT allowed", "start"
        it_behaves_like "NOT allowed", "reject"
        it_behaves_like "NOT allowed", "resume"
        it_behaves_like "NOT allowed", "stop"
        it_behaves_like "NOT allowed", "block"
        it_behaves_like "NOT allowed", "finish"
      end
    end
  end
end
