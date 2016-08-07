shared_examples_for :acts_as_notifiable do
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }

  describe "as public class methods" do
    describe "acts_as_notifiable" do
      it "includes Notifiable" do
        expect(described_class.respond_to?(:set_notifiable_class_defaults)).to be_truthy
      end

      context "with no options" do
        it "returns hash of specified options" do
          expect(described_class.acts_as_notifiable :users).to eq({})
        end
      end

      #TODO test other options
    end

    describe "available_notifiable_options" do
      it "returns list of available options in acts_as_notifiable" do
        expect(described_class.available_notifiable_options)
          .to eq([:targets, :group, :notifier, :parameters, :email_allowed, :notifiable_path])
      end
    end
  end
end