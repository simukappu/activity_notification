describe ActivityNotification::Mailer do
  include ActiveJob::TestHelper
  let(:notification) { create(:notification) }

  before do
    ActivityNotification::Mailer.deliveries.clear
    expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
  end

  describe "#send_notification_email" do
    context "with deliver_now" do
      context "as default" do
        before do
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
        end
  
        it "sends notification email now" do
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
        end
  
        it "sends to target email" do
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(notification.target.email)
        end
  
        it "sends from configured email in initializer" do
          expect(ActivityNotification::Mailer.deliveries.last.from[0])
            .to eq("please-change-me-at-config-initializers-activity_notification@example.com")
        end

        it "sends with default notification subject" do
          expect(ActivityNotification::Mailer.deliveries.last.subject)
            .to eq("Notification of Article")
        end
      end

      context "with default from parameter in mailer" do
        it "sends from configured email as default parameter" do
          class CustomMailer < ActivityNotification::Mailer
            default from: "test01@example.com"
          end
          CustomMailer.send_notification_email(notification).deliver_now
          expect(CustomMailer.deliveries.last.from[0])
            .to eq("test01@example.com")
        end
      end

      context "with email value as ActivityNotification.config.mailer_sender" do
        it "sends from configured email as ActivityNotification.config.mailer_sender" do
          ActivityNotification.config.mailer_sender = "test02@example.com"
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.from[0])
            .to eq("test02@example.com")
        end
      end

      context "with email proc as ActivityNotification.config.mailer_sender" do
        it "sends from configured email as ActivityNotification.config.mailer_sender" do
          ActivityNotification.config.mailer_sender =
            ->(notification){ notification.target_type == 'User' ? "test03@example.com" : "test04@example.com" }
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.from[0])
            .to eq("test03@example.com")
        end
      end

      context "with defined overriding_notification_email_key in notifiable model" do
        it "sends with configured notification subject in locale file as updated key" do
          module AdditionalMethods
            def overriding_notification_email_key(target, key)
              'comment.reply'
            end
          end
          notification.notifiable.extend(AdditionalMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.subject)
            .to eq("New comment to your article")
        end
      end
    end

    context "with deliver_later" do
      it "sends notification email later" do
        expect {
          perform_enqueued_jobs do
            ActivityNotification::Mailer.send_notification_email(notification).deliver_later
          end
        }.to change { ActivityNotification::Mailer.deliveries.size }.by(1)
        expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
      end

      it "sends notification email with active job queue" do
        expect {
            ActivityNotification::Mailer.send_notification_email(notification).deliver_later
        }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
      end
    end
  end
end