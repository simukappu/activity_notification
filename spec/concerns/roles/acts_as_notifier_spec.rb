describe ActivityNotification::ActsAsNotifier do
  let(:dummy_model_class) { Dummy::DummyBase }

  describe "as public class methods" do
    describe "acts_as_notifier" do
      it "have not included Notifier before calling" do
        expect(dummy_model_class.respond_to?(:available_as_notifier?)).to be_falsey
      end

      it "includes Notifier" do
        dummy_model_class.acts_as_notifier
        expect(dummy_model_class.respond_to?(:available_as_notifier?)).to be_truthy
        expect(dummy_model_class.available_as_notifier?).to be_truthy
      end
    end
  end
end