describe ActivityNotification::Config do
  describe "config.mailer" do
    let(:notification) { create(:notification) }

    context "as default" do
      it "is configured with ActivityNotification::Mailer" do
        expect(ActivityNotification::Mailer).to receive(:send_notification_email).and_call_original
        notification.send_notification_email send_later: false
      end
  
      it "is not configured with CustomNotificationMailer" do
        expect(CustomNotificationMailer).not_to receive(:send_notification_email).and_call_original
        notification.send_notification_email send_later: false
      end
    end

    context "when it is configured with CustomNotificationMailer" do
      before do
        ActivityNotification.config.mailer = 'CustomNotificationMailer'
        ActivityNotification::Notification.set_notification_mailer
      end

      after do
        ActivityNotification.config.mailer = 'ActivityNotification::Mailer'
        ActivityNotification::Notification.set_notification_mailer
      end

      it "is configured with CustomMailer" do
        expect(CustomNotificationMailer).to receive(:send_notification_email).and_call_original
        notification.send_notification_email send_later: false
      end
    end
  end
end
