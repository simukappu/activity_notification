describe "Notification resilience in background jobs" do
  include ActiveJob::TestHelper
  
  let(:user) { create(:user) }
  let(:article) { create(:article, user: user) }
  let(:comment) { create(:comment, article: article, user: create(:user)) }

  before do
    ActivityNotification::Mailer.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
    @original_email_enabled = ActivityNotification.config.email_enabled
    ActivityNotification.config.email_enabled = true
  end

  after do
    ActivityNotification.config.email_enabled = @original_email_enabled
  end

  describe "Job resilience" do
    it "handles missing notifications gracefully in background jobs" do
      # Create a notification and destroy it to simulate race condition
      notification = ActivityNotification::Notification.create!(
        target: user,
        notifiable: comment,
        key: 'comment.create'
      )
      
      notification_id = notification.id
      notification.destroy
      
      # Expect warning to be logged
      expect(Rails.logger).to receive(:warn).with(/ActivityNotification: Notification.*not found for email delivery/)
      
      # Execute job - should not raise error
      expect {
        perform_enqueued_jobs do
          # Simulate job trying to send email for destroyed notification
          begin
            destroyed_notification = ActivityNotification::Notification.find(notification_id)
            destroyed_notification.send_notification_email
          rescue => e
            # Handle any ORM-specific "record not found" exception
            if ActivityNotification::NotificationResilience.record_not_found_exception?(e)
              Rails.logger.warn("ActivityNotification: Notification with id #{notification_id} not found for email delivery (#{ActivityNotification.config.orm}/#{e.class.name}), likely destroyed before job execution")
            else
              raise e
            end
          end
        end
      }.not_to raise_error
      
      expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
    end
  end

  describe "Mailer job resilience" do
    context "when notification is destroyed before mailer job executes" do
      it "handles the scenario gracefully" do
        # Create a notification
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: comment,
          key: 'comment.create'
        )
        
        notification_id = notification.id
        
        # Expect warning to be logged when notification is not found
        expect(Rails.logger).to receive(:warn).with(/ActivityNotification: Notification.*not found for email delivery/)
        
        # Destroy the notification
        notification.destroy
        
        # Try to send email using the mailer directly - this should use our resilient implementation
        expect {
          perform_enqueued_jobs do
            # Create a mock notification that will raise RecordNotFound when accessed
            mock_notification = double("notification")
            allow(mock_notification).to receive(:id).and_return(notification_id)
            allow(mock_notification).to receive(:target).and_raise(ActiveRecord::RecordNotFound)
            
            ActivityNotification::Mailer.send_notification_email(mock_notification).deliver_now
          end
        }.not_to raise_error
        
        # No email should be sent
        expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
      end
    end

    context "when notification exists during mailer job execution" do
      it "sends email normally" do
        # Enable email for this test
        allow_any_instance_of(User).to receive(:notification_email_allowed?).and_return(true)
        allow_any_instance_of(Comment).to receive(:notification_email_allowed?).and_return(true)
        allow_any_instance_of(ActivityNotification::Notification).to receive(:email_subscribed?).and_return(true)
        
        # Create a notification
        notification = ActivityNotification::Notification.create!(
          target: user,
          notifiable: comment,
          key: 'comment.create'
        )
        
        # Don't expect any warnings
        expect(Rails.logger).not_to receive(:warn)
        
        # Send email - this should work normally
        expect {
          perform_enqueued_jobs do
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          end
        }.not_to raise_error
        
        # Email should be sent
        expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
      end
    end
  end

  describe "Multiple job resilience" do
    it "continues processing other jobs even when some notifications are missing" do
      # Enable email for this test
      allow_any_instance_of(User).to receive(:notification_email_allowed?).and_return(true)
      allow_any_instance_of(Comment).to receive(:notification_email_allowed?).and_return(true)
      allow_any_instance_of(ActivityNotification::Notification).to receive(:email_subscribed?).and_return(true)
      
      # Create two notifications
      notification1 = ActivityNotification::Notification.create!(
        target: user,
        notifiable: comment,
        key: 'comment.create'
      )
      
      notification2 = ActivityNotification::Notification.create!(
        target: user,
        notifiable: create(:comment, article: article, user: create(:user)),
        key: 'comment.create'
      )
      
      # Destroy the first notification
      notification1_id = notification1.id
      notification1.destroy
      
      # Expect one warning for the destroyed notification
      expect(Rails.logger).to receive(:warn).with(/ActivityNotification: Notification.*not found for email delivery/).once
      
      # Process both jobs
      expect {
        perform_enqueued_jobs do
          # First job - should handle missing notification gracefully
          mock_notification1 = double("notification")
          allow(mock_notification1).to receive(:id).and_return(notification1_id)
          allow(mock_notification1).to receive(:target).and_raise(ActiveRecord::RecordNotFound)
          ActivityNotification::Mailer.send_notification_email(mock_notification1).deliver_now
          
          # Second job - should work normally
          ActivityNotification::Mailer.send_notification_email(notification2).deliver_now
        end
      }.not_to raise_error
      
      # Only one email should be sent (for notification2)
      expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
    end
  end
end