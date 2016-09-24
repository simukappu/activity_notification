describe ActivityNotification::ActsAsNotifiable do
  let(:dummy_model_class) { Dummy::DummyBase }

  describe "as public class methods" do
    describe ".acts_as_notifiable" do
      it "have not included Notifiable before calling" do
        expect(dummy_model_class.respond_to?(:available_as_notifiable?)).to be_falsey
      end

      it "includes Notifiable" do
        dummy_model_class.acts_as_notifiable :users
        expect(dummy_model_class.respond_to?(:available_as_notifiable?)).to be_truthy
        expect(dummy_model_class.available_as_notifiable?).to be_truthy
      end

      context "with no options" do
        it "returns hash of specified options" do
          expect(dummy_model_class.acts_as_notifiable :users).to eq({})
        end
      end

      #TODO test other options
    end

    describe ".available_notifiable_options" do
      it "returns list of available options in acts_as_notifiable" do
        expect(dummy_model_class.available_notifiable_options)
          .to eq([:targets, :group, :notifier, :parameters, :email_allowed, :notifiable_path, :printable_notifiable_name, :printable_name])
      end
    end
  end
end