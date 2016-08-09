shared_examples_for :notifier do
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }

  describe "with association" do
    it "has many sent_notifications" do
      notification_1 = create(:notification, notifier: test_instance)
      notification_2 = create(:notification, notifier: test_instance)
      expect(test_instance.sent_notifications.count).to    eq(2)
      expect(test_instance.sent_notifications.earliest).to eq(notification_1)
      expect(test_instance.sent_notifications.latest).to   eq(notification_2)
    end
  end    

  describe "as public class methods" do
    describe "available_as_notifier?" do
      it "returns true" do
        expect(described_class.available_as_notifier?).to be_truthy
      end
    end
  end

end