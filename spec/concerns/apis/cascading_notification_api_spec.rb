shared_examples_for :cascading_notification_api do
  include ActiveJob::TestHelper
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }

  describe "as public instance methods" do
    describe "#cascade_notify" do
      before do
        ActiveJob::Base.queue_adapter = :test
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(true)
      end

      context "with valid cascade configuration" do
        it "enqueues a cascading notification job" do
          cascade_config = [
            { delay: 10.minutes, target: :slack }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
        end

        it "enqueues job with correct parameters" do
          cascade_config = [
            { delay: 10.minutes, target: :slack },
            { delay: 10.minutes, target: :email }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
            .with(test_instance.id, cascade_config, 0)
        end

        it "schedules job with correct delay" do
          cascade_config = [
            { delay: 15.minutes, target: :slack }
          ]
          
          start_time = Time.current
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
          
          # Verify the job was scheduled with approximately the right delay
          enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
          expected_time = start_time + 15.minutes
          expect(enqueued_job[:at].to_f).to be_within(1.0).of(expected_time.to_f)
        end

        it "returns true when cascade is initiated successfully" do
          cascade_config = [
            { delay: 10.minutes, target: :slack }
          ]
          
          result = test_instance.cascade_notify(cascade_config)
          expect(result).to be true
        end

        it "supports multiple cascade steps" do
          cascade_config = [
            { delay: 5.minutes, target: :slack },
            { delay: 10.minutes, target: :amazon_sns },
            { delay: 15.minutes, target: :email }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
        end
      end

      context "with trigger_first_immediately option" do
        it "triggers first target immediately and schedules remaining" do
          cascade_config = [
            { delay: 5.minutes, target: :slack },
            { delay: 10.minutes, target: :email }
          ]
          
          mock_optional_target = double('OptionalTarget')
          allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
          expect(mock_optional_target).to receive(:notify).with(test_instance, {}).and_return(true)
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([mock_optional_target])
          
          expect {
            test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
          }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
            .with(test_instance.id, cascade_config[1..-1], 0)
        end

        it "only triggers first target when single step with trigger_first_immediately" do
          cascade_config = [
            { delay: 5.minutes, target: :slack }
          ]
          
          mock_optional_target = double('OptionalTarget')
          allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
          expect(mock_optional_target).to receive(:notify).with(test_instance, {}).and_return(true)
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([mock_optional_target])
          
          expect {
            test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
          }.not_to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
        end

        it "passes custom options to first target when triggered immediately" do
          cascade_config = [
            { delay: 5.minutes, target: :slack, options: { channel: '#urgent' } }
          ]
          
          mock_optional_target = double('OptionalTarget')
          allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
          expect(mock_optional_target).to receive(:notify).with(test_instance, { channel: '#urgent' }).and_return(true)
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([mock_optional_target])
          
          test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
        end

        it "logs success when first target is triggered immediately" do
          allow(Rails.logger).to receive(:info)
          
          cascade_config = [
            { delay: 5.minutes, target: :slack }
          ]
          
          mock_optional_target = double('OptionalTarget')
          allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
          allow(mock_optional_target).to receive(:notify).and_return(true)
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([mock_optional_target])
          
          test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
          expect(Rails.logger).to have_received(:info).with("Successfully triggered optional target 'slack' for notification #{test_instance.id}")
        end

        it "logs warning when first target is not configured" do
          allow(Rails.logger).to receive(:warn)
          
          cascade_config = [
            { delay: 5.minutes, target: :nonexistent }
          ]
          
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([])
          
          test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
          expect(Rails.logger).to have_received(:warn).with("Optional target 'nonexistent' not found for notification #{test_instance.id}")
        end

        it "logs info when first target is not subscribed" do
          allow(Rails.logger).to receive(:info)
          
          cascade_config = [
            { delay: 5.minutes, target: :slack }
          ]
          
          mock_optional_target = double('OptionalTarget')
          allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([mock_optional_target])
          allow(test_instance).to receive(:optional_target_subscribed?).and_return(false)
          
          test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
          expect(Rails.logger).to have_received(:info).with("Target not subscribed to optional target 'slack' for notification #{test_instance.id}")
        end

        it "logs error and handles error when first target fails and rescue is enabled" do
          allow(Rails.logger).to receive(:error)
          allow(ActivityNotification.config).to receive(:rescue_optional_target_errors).and_return(true)
          
          cascade_config = [
            { delay: 5.minutes, target: :slack }
          ]
          
          mock_optional_target = double('OptionalTarget')
          allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
          allow(mock_optional_target).to receive(:notify).and_raise(StandardError.new("Connection failed"))
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([mock_optional_target])
          
          # Should not raise error, but return error object
          result = test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
          expect(result).to be true  # cascade_notify returns true even if first step fails
          
          expect(Rails.logger).to have_received(:error).with("Failed to trigger optional target 'slack' for notification #{test_instance.id}: Connection failed")
        end

        it "logs error and raises when first target fails and rescue is disabled" do
          allow(Rails.logger).to receive(:error)
          allow(ActivityNotification.config).to receive(:rescue_optional_target_errors).and_return(false)
          
          cascade_config = [
            { delay: 5.minutes, target: :slack }
          ]
          
          mock_optional_target = double('OptionalTarget')
          allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
          allow(mock_optional_target).to receive(:notify).and_raise(StandardError.new("Connection failed"))
          allow_any_instance_of(test_instance.notifiable.class).to receive(:optional_targets).and_return([mock_optional_target])
          
          expect {
            test_instance.cascade_notify(cascade_config, trigger_first_immediately: true)
          }.to raise_error(StandardError, "Connection failed")
          
          expect(Rails.logger).to have_received(:error).with("Failed to trigger optional target 'slack' for notification #{test_instance.id}: Connection failed")
        end
      end

      context "with validation disabled" do
        it "does not validate configuration when validate is false" do
          invalid_config = [
            { target: :slack }  # missing delay
          ]
          
          expect {
            test_instance.cascade_notify(invalid_config, validate: false)
          }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
        end

        it "still returns false for empty config even without validation" do
          result = test_instance.cascade_notify([], validate: false)
          expect(result).to be false
        end
      end

      context "with invalid cascade configuration" do
        it "raises ArgumentError for nil configuration" do
          expect {
            test_instance.cascade_notify(nil)
          }.to raise_error(ArgumentError, /Invalid cascade configuration/)
        end

        it "raises ArgumentError for non-array configuration" do
          expect {
            test_instance.cascade_notify({ delay: 10.minutes, target: :slack })
          }.to raise_error(ArgumentError, /Invalid cascade configuration/)
        end

        it "raises ArgumentError for empty array" do
          expect {
            test_instance.cascade_notify([])
          }.to raise_error(ArgumentError, /Invalid cascade configuration/)
        end

        it "raises ArgumentError for missing target" do
          cascade_config = [
            { delay: 10.minutes }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to raise_error(ArgumentError, /missing required :target parameter/)
        end

        it "raises ArgumentError for missing delay" do
          cascade_config = [
            { target: :slack }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to raise_error(ArgumentError, /missing :delay parameter/)
        end

        it "raises ArgumentError for invalid target type" do
          cascade_config = [
            { delay: 10.minutes, target: 123 }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to raise_error(ArgumentError, /:target must be a Symbol or String/)
        end

        it "raises ArgumentError for invalid options type" do
          cascade_config = [
            { delay: 10.minutes, target: :slack, options: "invalid" }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.to raise_error(ArgumentError, /:options must be a Hash/)
        end
      end

      context "with opened notification" do
        it "returns false if notification is already opened" do
          test_instance.open!
          
          cascade_config = [
            { delay: 10.minutes, target: :slack }
          ]
          
          result = test_instance.cascade_notify(cascade_config)
          expect(result).to be false
        end

        it "does not enqueue job if notification is opened" do
          test_instance.open!
          
          cascade_config = [
            { delay: 10.minutes, target: :slack }
          ]
          
          expect {
            test_instance.cascade_notify(cascade_config)
          }.not_to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
        end
      end

      context "without ActiveJob" do
        it "returns false and logs error if ActiveJob is not available" do
          allow(Rails.logger).to receive(:error)
          
          # Temporarily hide both ActiveJob and CascadingNotificationJob
          hide_const("ActiveJob")
          hide_const("ActivityNotification::CascadingNotificationJob")
          
          cascade_config = [
            { delay: 10.minutes, target: :slack }
          ]
          
          result = test_instance.cascade_notify(cascade_config)
          expect(result).to be false
          expect(Rails.logger).to have_received(:error).with("ActiveJob or CascadingNotificationJob not available for cascading notifications")
        end
      end
    end

    describe "#validate_cascade_config" do
      it "returns valid for correct configuration" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it "returns invalid for nil configuration" do
        result = test_instance.validate_cascade_config(nil)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("cascade_config cannot be nil")
      end

      it "returns invalid for non-array configuration" do
        result = test_instance.validate_cascade_config("not an array")
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("cascade_config must be an Array")
      end

      it "returns invalid for empty array" do
        result = test_instance.validate_cascade_config([])
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("cascade_config cannot be empty")
      end

      it "returns invalid when step is not a Hash" do
        cascade_config = ["invalid step"]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Step 0 must be a Hash")
      end

      it "returns invalid when target is missing" do
        cascade_config = [
          { delay: 10.minutes }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Step 0 missing required :target parameter")
      end

      it "returns invalid when delay is missing" do
        cascade_config = [
          { target: :slack }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Step 0 missing :delay parameter")
      end

      it "returns invalid when target is not Symbol or String" do
        cascade_config = [
          { delay: 10.minutes, target: 123 }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Step 0 :target must be a Symbol or String")
      end

      it "returns invalid when delay is not valid" do
        cascade_config = [
          { delay: "not a duration", target: :slack }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Step 0 :delay must be an ActiveSupport::Duration or Numeric (seconds)")
      end

      it "returns invalid when options is not a Hash" do
        cascade_config = [
          { delay: 10.minutes, target: :slack, options: "invalid" }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Step 0 :options must be a Hash")
      end

      it "accepts numeric delay (seconds)" do
        cascade_config = [
          { delay: 600, target: :slack }  # 600 seconds = 10 minutes
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be true
      end

      it "accepts string target" do
        cascade_config = [
          { delay: 10.minutes, target: "slack" }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be true
      end

      it "accepts valid options Hash" do
        cascade_config = [
          { delay: 10.minutes, target: :slack, options: { channel: '#alerts' } }
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be true
      end

      it "validates multiple steps" do
        cascade_config = [
          { delay: 5.minutes, target: :slack },
          { delay: 10.minutes, target: :email },
          { target: :sms }  # missing delay
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include("Step 2 missing :delay parameter")
      end

      it "collects multiple errors" do
        cascade_config = [
          { delay: 10.minutes },  # missing target
          { target: :slack }      # missing delay
        ]
        
        result = test_instance.validate_cascade_config(cascade_config)
        expect(result[:valid]).to be false
        expect(result[:errors].length).to eq(2)
        expect(result[:errors]).to include("Step 0 missing required :target parameter")
        expect(result[:errors]).to include("Step 1 missing :delay parameter")
      end
    end

    describe "#cascade_in_progress?" do
      it "returns false by default" do
        expect(test_instance.cascade_in_progress?).to be false
      end
    end
  end

  describe "integration scenarios" do
    before do
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      
      @author_user = create(:confirmed_user)
      @user        = create(:confirmed_user)
      @article     = create(:article, user: @author_user)
      @comment     = create(:comment, article: @article, user: @user)
      
      # Create notification explicitly
      @notification = create(:notification, target: @author_user, notifiable: @comment)
      
      allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(true)
    end

    it "supports complex multi-step cascades with different delays" do
      cascade_config = [
        { delay: 5.minutes, target: :slack, options: { channel: '#alerts' } },
        { delay: 10.minutes, target: :amazon_sns, options: { subject: 'Urgent Notification' } },
        { delay: 30.minutes, target: :email }
      ]
      
      result = @notification.cascade_notify(cascade_config)
      expect(result).to be true
    end

    it "works with real notification from comment creation" do
      expect(@notification).to be_present
      expect(@notification).to be_unopened
      
      cascade_config = [
        { delay: 10.minutes, target: :slack }
      ]
      
      expect {
        @notification.cascade_notify(cascade_config)
      }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
    end
  end
end
