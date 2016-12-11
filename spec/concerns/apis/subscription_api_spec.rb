shared_examples_for :subscription_api do
  include ActiveJob::TestHelper
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }

  describe "as public instance methods" do
    describe "#subscribe" do
      before do
        test_instance.unsubscribe
      end

      it "returns if successfully updated subscription instance" do
        expect(test_instance.subscribe).to be_truthy
      end

      context "as default" do
        it "subscribe with current time" do
          expect(test_instance.subscribing).to                   eq(false)
          expect(test_instance.subscribing_to_email).to          eq(false)
          Timecop.freeze(DateTime.now)
          test_instance.subscribe
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(true)
          expect(test_instance.subscribed_at).to                 eq(DateTime.now)
          expect(test_instance.subscribed_to_email_at).to        eq(DateTime.now)
          Timecop.return
        end
      end

      context "with subscribed_at option" do
        it "subscribe with specified time" do
          expect(test_instance.subscribing).to                   eq(false)
          expect(test_instance.subscribing_to_email).to          eq(false)
          subscribed_at = DateTime.now - 1.months
          test_instance.subscribe(subscribed_at: subscribed_at)
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(true)
          expect(test_instance.subscribed_at).to                 eq(subscribed_at)
          expect(test_instance.subscribed_to_email_at).to        eq(subscribed_at)
        end
      end

      context "with false as with_email_subscription" do
        it "does not subscribe to email" do
          expect(test_instance.subscribing).to                   eq(false)
          expect(test_instance.subscribing_to_email).to          eq(false)
          test_instance.subscribe(with_email_subscription: false)
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(false)
        end
      end
    end

    describe "#unsubscribe" do
      it "returns if successfully updated subscription instance" do
        expect(test_instance.subscribe).to be_truthy
      end

      context "as default" do
        it "unsubscribe with current time" do
          expect(test_instance.subscribing).to                     eq(true)
          expect(test_instance.subscribing_to_email).to            eq(true)
          Timecop.freeze(DateTime.now)
          test_instance.unsubscribe
          expect(test_instance.subscribing).to                     eq(false)
          expect(test_instance.subscribing_to_email).to            eq(false)
          expect(test_instance.unsubscribed_at).to                 eq(DateTime.now)
          expect(test_instance.unsubscribed_to_email_at).to        eq(DateTime.now)
          Timecop.return
        end
      end

      context "with unsubscribed_at option" do
        it "unsubscribe with specified time" do
          expect(test_instance.subscribing).to                     eq(true)
          expect(test_instance.subscribing_to_email).to            eq(true)
          unsubscribed_at = DateTime.now - 1.months
          test_instance.unsubscribe(unsubscribed_at: unsubscribed_at)
          expect(test_instance.subscribing).to                     eq(false)
          expect(test_instance.subscribing_to_email).to            eq(false)
          expect(test_instance.unsubscribed_at).to                 eq(unsubscribed_at)
          expect(test_instance.unsubscribed_to_email_at).to        eq(unsubscribed_at)
        end
      end
    end

    describe "#subscribe_to_email" do
      before do
        test_instance.unsubscribe_to_email
      end

      context "for subscribing instance" do
        it "returns true as successfully updated subscription instance" do
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(false)
          expect(test_instance.subscribe_to_email).to be_truthy
        end
      end

      context "for not subscribing instance" do
        it "returns false as successfully updated subscription instance" do
          test_instance.unsubscribe
          expect(test_instance.subscribing).to                   eq(false)
          expect(test_instance.subscribing_to_email).to          eq(false)
          expect(test_instance.subscribe_to_email).to be_falsey
        end
      end

      context "as default" do
        it "subscribe_to_email with current time" do
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(false)
          Timecop.freeze(DateTime.now)
          test_instance.subscribe_to_email
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(true)
          expect(test_instance.subscribed_to_email_at).to        eq(DateTime.now)
          Timecop.return
        end
      end

      context "with subscribed_to_email_at option" do
        it "subscribe with specified time" do
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(false)
          subscribed_to_email_at = DateTime.now - 1.months
          test_instance.subscribe_to_email(subscribed_to_email_at: subscribed_to_email_at)
          expect(test_instance.subscribing).to                   eq(true)
          expect(test_instance.subscribing_to_email).to          eq(true)
          expect(test_instance.subscribed_to_email_at).to        eq(subscribed_to_email_at)
        end
      end
    end

    describe "#unsubscribe_to_email" do
      it "returns if successfully updated subscription instance" do
        expect(test_instance.unsubscribe_to_email).to be_truthy
      end

      context "as default" do
        it "unsubscribe_to_email with current time" do
          expect(test_instance.subscribing).to                     eq(true)
          expect(test_instance.subscribing_to_email).to            eq(true)
          Timecop.freeze(DateTime.now)
          test_instance.unsubscribe_to_email
          expect(test_instance.subscribing).to                     eq(true)
          expect(test_instance.subscribing_to_email).to            eq(false)
          expect(test_instance.unsubscribed_to_email_at).to        eq(DateTime.now)
          Timecop.return
        end
      end

      context "with unsubscribed_to_email_at option" do
        it "unsubscribe with specified time" do
          expect(test_instance.subscribing).to                     eq(true)
          expect(test_instance.subscribing_to_email).to            eq(true)
          unsubscribed_to_email_at = DateTime.now - 1.months
          test_instance.unsubscribe_to_email(unsubscribed_to_email_at: unsubscribed_to_email_at)
          expect(test_instance.subscribing).to                     eq(true)
          expect(test_instance.subscribing_to_email).to            eq(false)
          expect(test_instance.unsubscribed_to_email_at).to        eq(unsubscribed_to_email_at)
        end
      end
    end

  end
end