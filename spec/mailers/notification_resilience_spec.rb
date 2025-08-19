describe ActivityNotification::NotificationResilience do
  include ActiveJob::TestHelper
  let(:notification) { create(:notification) }
  let(:test_target) { notification.target }
  let(:notifications) { [create(:notification, target: test_target), create(:notification, target: test_target)] }
  let(:batch_key) { 'test_batch_key' }

  before do
    ActivityNotification::Mailer.deliveries.clear
    expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
  end

  describe "ORM exception handling" do
    describe ".current_orm" do
      it "returns the configured ORM" do
        expect(ActivityNotification::NotificationResilience.current_orm).to eq(ActivityNotification.config.orm)
      end
    end

    describe ".record_not_found_exception_class" do
      context "with ActiveRecord ORM" do
        before { allow(ActivityNotification.config).to receive(:orm).and_return(:active_record) }
        
        it "returns ActiveRecord::RecordNotFound" do
          expect(ActivityNotification::NotificationResilience.record_not_found_exception_class).to eq(ActiveRecord::RecordNotFound)
        end
      end

      context "with Mongoid ORM" do
        before { allow(ActivityNotification.config).to receive(:orm).and_return(:mongoid) }
        
        it "returns Mongoid exception class if available" do
          if defined?(Mongoid::Errors::DocumentNotFound)
            expect(ActivityNotification::NotificationResilience.record_not_found_exception_class).to eq(Mongoid::Errors::DocumentNotFound)
          else
            expect(ActivityNotification::NotificationResilience.record_not_found_exception_class).to be_nil
          end
        end
      end

      context "with Dynamoid ORM" do
        before { allow(ActivityNotification.config).to receive(:orm).and_return(:dynamoid) }
        
        it "returns Dynamoid exception class if available" do
          if defined?(Dynamoid::Errors::RecordNotFound)
            expect(ActivityNotification::NotificationResilience.record_not_found_exception_class).to eq(Dynamoid::Errors::RecordNotFound)
          else
            expect(ActivityNotification::NotificationResilience.record_not_found_exception_class).to be_nil
          end
        end
      end

      context "with unavailable ORM exception class" do
        around do |example|
          # Temporarily modify the ORM_EXCEPTIONS constant
          original_exceptions = ActivityNotification::NotificationResilience::ORM_EXCEPTIONS
          ActivityNotification::NotificationResilience.send(:remove_const, :ORM_EXCEPTIONS)
          ActivityNotification::NotificationResilience.const_set(:ORM_EXCEPTIONS, {
            active_record: 'NonExistent::ExceptionClass',
            mongoid: 'Mongoid::Errors::DocumentNotFound', 
            dynamoid: 'Dynamoid::Errors::RecordNotFound'
          })
          
          example.run
          
          # Restore original constant
          ActivityNotification::NotificationResilience.send(:remove_const, :ORM_EXCEPTIONS)
          ActivityNotification::NotificationResilience.const_set(:ORM_EXCEPTIONS, original_exceptions)
        end
        
        before { allow(ActivityNotification.config).to receive(:orm).and_return(:active_record) }
        
        it "returns nil when exception class is not available" do
          expect(ActivityNotification::NotificationResilience.record_not_found_exception_class).to be_nil
        end
      end
    end

    describe ".record_not_found_exception?" do
      it "returns true for ActiveRecord::RecordNotFound" do
        exception = ActiveRecord::RecordNotFound.new("Test error")
        expect(ActivityNotification::NotificationResilience.record_not_found_exception?(exception)).to be_truthy
      end

      it "returns false for other exceptions" do
        exception = StandardError.new("Test error")
        expect(ActivityNotification::NotificationResilience.record_not_found_exception?(exception)).to be_falsy
      end

      context "when exception class constantize raises NameError" do
        around do |example|
          # Temporarily modify the ORM_EXCEPTIONS constant
          original_exceptions = ActivityNotification::NotificationResilience::ORM_EXCEPTIONS
          ActivityNotification::NotificationResilience.send(:remove_const, :ORM_EXCEPTIONS)
          ActivityNotification::NotificationResilience.const_set(:ORM_EXCEPTIONS, {
            active_record: 'NonExistent::ExceptionClass1',
            mongoid: 'NonExistent::ExceptionClass2', 
            dynamoid: 'NonExistent::ExceptionClass3'
          })
          
          example.run
          
          # Restore original constant
          ActivityNotification::NotificationResilience.send(:remove_const, :ORM_EXCEPTIONS)
          ActivityNotification::NotificationResilience.const_set(:ORM_EXCEPTIONS, original_exceptions)
        end
        
        it "returns false when all exception classes are unavailable" do
          exception = StandardError.new("Test error")
          # Should return false because all exception classes will raise NameError
          expect(ActivityNotification::NotificationResilience.record_not_found_exception?(exception)).to be_falsy
        end
      end
    end
  end

  describe "Resilient email sending" do
    describe "when notification is destroyed before email job executes" do
      let(:destroyed_notification) { create(:notification) }
      
      before do
        destroyed_notification_id = destroyed_notification.id
        destroyed_notification.destroy
        
        # Mock the notification to simulate the scenario where the job tries to access a destroyed notification
        allow(ActivityNotification::Notification).to receive(:find).with(destroyed_notification_id).and_raise(ActiveRecord::RecordNotFound)
      end

      context "with send_notification_email" do
        it "handles missing notification gracefully and logs warning" do
          expect(Rails.logger).to receive(:warn).with(/ActivityNotification: Notification.*not found for email delivery/)
          
          # Create a mock notification that will raise RecordNotFound when accessed
          mock_notification = double("notification")
          allow(mock_notification).to receive(:id).and_return(999)
          allow(mock_notification).to receive(:target).and_raise(ActiveRecord::RecordNotFound)
          
          result = nil
          expect {
            result = ActivityNotification::Mailer.send_notification_email(mock_notification).deliver_now
          }.not_to raise_error
          
          expect(result).to be_nil
          expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
        end
      end

      context "with send_batch_notification_email" do
        it "handles missing notifications gracefully and logs warning" do
          expect(Rails.logger).to receive(:warn).with(/ActivityNotification: Notification.*not found for email delivery/)
          
          # Create mock notifications that will raise RecordNotFound when accessed
          mock_notifications = [double("notification")]
          allow(mock_notifications.first).to receive(:id).and_return(999)
          allow(mock_notifications.first).to receive(:key).and_return("test.key")
          allow(mock_notifications.first).to receive(:notifiable).and_raise(ActiveRecord::RecordNotFound)
          
          result = nil
          expect {
            result = ActivityNotification::Mailer.send_batch_notification_email(test_target, mock_notifications, batch_key).deliver_now
          }.not_to raise_error
          
          expect(result).to be_nil
          expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
        end
      end
    end

    describe "when notification exists" do
      context "with send_notification_email" do
        it "sends email normally" do
          expect(Rails.logger).not_to receive(:warn)
          
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(notification.target.email)
        end
      end

      context "with send_batch_notification_email" do
        it "sends batch email normally" do
          expect(Rails.logger).not_to receive(:warn)
          
          ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_now
          
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(test_target.email)
        end
      end
    end
  end

  describe "Class methods (when included in a class)" do
    let(:test_class) { Class.new { include ActivityNotification::NotificationResilience } }
    
    describe "class method exception handling with NameError" do
      around do |example|
        # Temporarily modify the ORM_EXCEPTIONS constant
        original_exceptions = ActivityNotification::NotificationResilience::ORM_EXCEPTIONS
        ActivityNotification::NotificationResilience.send(:remove_const, :ORM_EXCEPTIONS)
        ActivityNotification::NotificationResilience.const_set(:ORM_EXCEPTIONS, {
          active_record: 'NonExistent::ClassMethodException',
          mongoid: 'Mongoid::Errors::DocumentNotFound', 
          dynamoid: 'Dynamoid::Errors::RecordNotFound'
        })
        
        example.run
        
        # Restore original constant
        ActivityNotification::NotificationResilience.send(:remove_const, :ORM_EXCEPTIONS)
        ActivityNotification::NotificationResilience.const_set(:ORM_EXCEPTIONS, original_exceptions)
      end
      
      before { allow(ActivityNotification.config).to receive(:orm).and_return(:active_record) }
      
      it "returns nil when exception class is not available (class method)" do
        expect(test_class.record_not_found_exception_class).to be_nil
      end
      
      it "returns false when exception class constantize raises NameError (class method)" do
        exception = StandardError.new("Test error")
        expect(test_class.record_not_found_exception?(exception)).to be_falsy
      end
    end
  end

  describe "Logging behavior" do
    let(:mock_notification) { double("notification", id: 123) }
    let(:resilience_instance) { Class.new { include ActivityNotification::NotificationResilience }.new }
    
    it "logs appropriate warning message with notification ID" do
      exception = ActiveRecord::RecordNotFound.new("Test error")
      
      expect(Rails.logger).to receive(:warn).with(
        /ActivityNotification: Notification with id 123 not found for email delivery.*likely destroyed before job execution/
      )
      
      resilience_instance.send(:log_missing_notification, 123, exception)
    end

    it "logs warning message with context information" do
      exception = ActiveRecord::RecordNotFound.new("Test error")
      context = { target: "User", key: "comment.create" }
      
      expect(Rails.logger).to receive(:warn).with(
        /ActivityNotification: Notification with id 123 not found for email delivery.*target: User, key: comment\.create/
      )
      
      resilience_instance.send(:log_missing_notification, 123, exception, context)
    end

    it "logs warning message without ID when not provided" do
      exception = ActiveRecord::RecordNotFound.new("Test error")
      
      expect(Rails.logger).to receive(:warn).with(
        /ActivityNotification: Notification not found for email delivery.*likely destroyed before job execution/
      )
      
      resilience_instance.send(:log_missing_notification, nil, exception)
    end
  end
end