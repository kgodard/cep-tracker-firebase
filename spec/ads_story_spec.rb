require_relative '../ads_story.rb'

describe AdsStory do
  let(:azure_bug_json) {
    {"fields"=>
      {"Custom.TargetedProject"=>"#{targeted_project}",
       "Microsoft.VSTS.Scheduling.StoryPoints"=>1.0,
       "System.AreaLevel3"=>"DemDude",
       "System.BoardColumn"=>"Development",
       "System.Id"=>1927624,
       "System.IterationLevel3"=>"LaPasta",
       "System.State"=>"New",
       "System.Tags"=>"",
       "System.Title"=>"Test Title",
       "System.WorkItemType"=>"Bug",
      },
     "id"=>1927624,
     "url"=>
      "https://dev.azure.com/itron/c8002d3e-f4a9-4aea-9ab8-230027996c53/_apis/wit/workItems/1927624"
    }
  }

  subject { AdsStory.new(id: 777) }

  context "A bug" do
    before do
      expect_any_instance_of(AdsStory).to receive(:az_fetch).and_return(azure_bug_json)
    end

    describe "on load" do
      let(:targeted_project) { 'something' }

      it "sets targeted project field" do
        expect(subject.targeted_project).to eq(targeted_project)
      end
    end

    describe "on update" do
      let(:targeted_project) { '' }

      context "when targeted_project is blank" do
        before do
          expect(subject).to receive(:update_fields).with({"Custom.TargetedProject" => AdsStory::DEFAULT_TARGETED_PROJECT})
          expect(subject).to receive(:az_update)
          expect(subject).to receive(:fetch_and_load)
        end

        it "updates the targeted project field" do
          subject.start
        end
      end
    end
  end
end
