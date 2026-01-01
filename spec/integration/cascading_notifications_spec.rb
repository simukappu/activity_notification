describe "Cascading Notifications Integration", type: :integration do
  include ActiveSupport::Testing::TimeHelpers
  
  before do
    # Use the test adapter for ActiveJob
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    
    # Create test users and content
    @author_user = create(:confirmed_user)
    @user        = create(:confirmed_user)
    @article     = create(:article, user: @author_user)
    @comment     = create(:comment, article: @article, user: @user)
    
    # Create notification explicitly
    @notification = create(:notification, target: @author_user, notifiable: @comment)
    
    # Mock optional target subscriptions
    allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(true)
  end

  describe "complete cascade flow" do
    it "executes full cascade sequence when notification remains unread" do
      # Create mock optional targets
      slack_target = double('SlackTarget')
      allow(slack_target).to receive(:to_optional_target_name).and_return(:slack)
      allow(slack_target).to receive(:notify).and_return(true)
      
      email_target = double('EmailTarget')
      allow(email_target).to receive(:to_optional_target_name).and_return(:email)
      allow(email_target).to receive(:notify).and_return(true)
      
      sms_target = double('SMSTarget')
      allow(sms_target).to receive(:to_optional_target_name).and_return(:sms)
      allow(sms_target).to receive(:notify).and_return(true)
      
      allow_any_instance_of(Comment).to receive(:optional_targets).and_return([slack_target, email_target, sms_target])
      
      # Configure cascade: Slack → Email → SMS with increasing delays
      cascade_config = [
        { delay: 5.minutes, target: :slack, options: { channel: '#general' } },
        { delay: 10.minutes, target: :email },
        { delay: 30.minutes, target: :sms, options: { urgent: true } }
      ]
      
      # Capture the current time for consistent time calculations
      start_time = Time.current
      
      # Start the cascade
      expect(@notification.cascade_notify(cascade_config)).to be true
      
      # Verify first job is scheduled
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
      first_job = ActiveJob::Base.queue_adapter.enqueued_jobs.first
      expect(first_job[:job]).to eq(ActivityNotification::CascadingNotificationJob)
      expect(first_job[:at].to_f).to be_within(1.0).of((start_time + 5.minutes).to_f)
      
      # Simulate time passing and execute first job
      travel_to(start_time + 5.minutes) do
        expect(slack_target).to receive(:notify).with(@notification, { channel: '#general' })
        
        # Clear queue and perform the job
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 0)
        
        # Verify Slack was triggered successfully
        expect(result).to eq({ slack: :success })
        
        # Verify next job was scheduled for email (10 minutes from current travelled time)
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
        next_job = ActiveJob::Base.queue_adapter.enqueued_jobs.first
        expect(next_job[:at].to_f).to be_within(1.0).of((start_time + 15.minutes).to_f)
      end
      
      # Simulate more time passing and execute second job
      travel_to(start_time + 15.minutes) do
        expect(email_target).to receive(:notify).with(@notification, {})
        
        # Clear queue and perform the job
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 1)
        
        # Verify email was triggered successfully
        expect(result).to eq({ email: :success })
        
        # Verify next job was scheduled for SMS (30 minutes from current travelled time)
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
        next_job = ActiveJob::Base.queue_adapter.enqueued_jobs.first
        expect(next_job[:at].to_f).to be_within(1.0).of((start_time + 45.minutes).to_f)
      end
      
      # Simulate final time passing and execute third job
      travel_to(start_time + 45.minutes) do
        expect(sms_target).to receive(:notify).with(@notification, { urgent: true })
        
        # Clear queue and perform the job
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 2)
        
        # Verify SMS was triggered successfully
        expect(result).to eq({ sms: :success })
        
        # Verify no more jobs are scheduled
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(0)
      end
    end

    it "stops cascade when notification is read mid-sequence" do
      # Create mock optional target
      slack_target = double('SlackTarget')
      allow(slack_target).to receive(:to_optional_target_name).and_return(:slack)
      allow(slack_target).to receive(:notify).and_return(true)
      
      allow_any_instance_of(Comment).to receive(:optional_targets).and_return([slack_target])
      
      cascade_config = [
        { delay: 5.minutes, target: :slack },
        { delay: 10.minutes, target: :email }
      ]
      
      start_time = Time.current
      
      # Start the cascade
      @notification.cascade_notify(cascade_config)
      
      # Simulate first job execution
      travel_to(start_time + 5.minutes) do
        expect(slack_target).to receive(:notify).with(@notification, {})
        
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        job_instance = ActivityNotification::CascadingNotificationJob.new
        job_instance.perform(@notification.id, cascade_config, 0)
        
        # Verify next job was scheduled
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
      end
      
      # User reads the notification before second job executes
      travel_to(start_time + 15.minutes) do
        @notification.open!
        expect(@notification.opened?).to be true
        
        # Execute the second job - should return nil because notification is read
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 1)
        
        expect(result).to be_nil
      end
    end

    it "handles errors gracefully and continues cascade" do
      # Create mock optional targets
      failing_slack_target = double('FailingSlackTarget')
      allow(failing_slack_target).to receive(:to_optional_target_name).and_return(:slack)
      allow(failing_slack_target).to receive(:notify).and_raise(StandardError.new("Slack API error"))
      
      email_target = double('EmailTarget')
      allow(email_target).to receive(:to_optional_target_name).and_return(:email)
      allow(email_target).to receive(:notify).and_return(true)
      
      allow_any_instance_of(Comment).to receive(:optional_targets).and_return([failing_slack_target, email_target])
      
      # Enable error rescue
      allow(ActivityNotification.config).to receive(:rescue_optional_target_errors).and_return(true)
      
      cascade_config = [
        { delay: 5.minutes, target: :slack },
        { delay: 10.minutes, target: :email }
      ]
      
      start_time = Time.current
      
      @notification.cascade_notify(cascade_config)
      
      # Simulate first job execution with failure
      travel_to(start_time + 5.minutes) do
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 0)
        
        # Verify error was captured
        expect(result[:slack]).to be_a(StandardError)
        expect(result[:slack].message).to eq("Slack API error")
        
        # Verify next job was still scheduled despite the error
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
      end
      
      # Simulate second job execution (should succeed)
      travel_to(start_time + 15.minutes) do
        expect(email_target).to receive(:notify).with(@notification, {})
        
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 1)
        
        expect(result).to eq({ email: :success })
      end
    end

    it "handles non-subscribed targets gracefully" do
      # Create mock optional target
      slack_target = double('SlackTarget')
      allow(slack_target).to receive(:to_optional_target_name).and_return(:slack)
      
      allow_any_instance_of(Comment).to receive(:optional_targets).and_return([slack_target])
      
      # Mock subscription check to return false
      allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(false)
      
      cascade_config = [
        { delay: 5.minutes, target: :slack }
      ]
      
      start_time = Time.current
      
      @notification.cascade_notify(cascade_config)
      
      # Simulate job execution
      travel_to(start_time + 5.minutes) do
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 0)
        
        # Verify target was not triggered due to subscription
        expect(result).to eq({ slack: :not_subscribed })
      end
    end

    it "handles missing optional targets gracefully" do
      # Mock empty optional targets
      allow_any_instance_of(Comment).to receive(:optional_targets).and_return([])
      
      cascade_config = [
        { delay: 5.minutes, target: :nonexistent_target }
      ]
      
      start_time = Time.current
      
      @notification.cascade_notify(cascade_config)
      
      # Simulate job execution
      travel_to(start_time + 5.minutes) do
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 0)
        
        # Verify appropriate response for missing target
        expect(result).to eq({ nonexistent_target: :not_configured })
      end
    end
  end

  describe "trigger_first_immediately feature" do
    it "triggers first target immediately then schedules remaining" do
      # Create mock optional targets
      slack_target = double('SlackTarget')
      allow(slack_target).to receive(:to_optional_target_name).and_return(:slack)
      allow(slack_target).to receive(:notify).and_return(true)
      
      email_target = double('EmailTarget')
      allow(email_target).to receive(:to_optional_target_name).and_return(:email)
      allow(email_target).to receive(:notify).and_return(true)
      
      allow_any_instance_of(Comment).to receive(:optional_targets).and_return([slack_target, email_target])
      
      cascade_config = [
        { delay: 5.minutes, target: :slack },
        { delay: 10.minutes, target: :email }
      ]
      
      start_time = Time.current
      
      # Expect immediate execution of first target
      expect(slack_target).to receive(:notify).with(@notification, {})
      
      result = @notification.cascade_notify(cascade_config, trigger_first_immediately: true)
      expect(result).to be true
      
      # Verify remaining cascade was scheduled
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
      scheduled_job = ActiveJob::Base.queue_adapter.enqueued_jobs.first
      expect(scheduled_job[:at].to_f).to be_within(1.0).of((start_time + 10.minutes).to_f)
    end
  end

  describe "edge cases" do
    it "handles deleted notifications gracefully" do
      cascade_config = [
        { delay: 5.minutes, target: :slack }
      ]
      
      start_time = Time.current
      
      @notification.cascade_notify(cascade_config)
      
      # Delete the notification
      notification_id = @notification.id
      @notification.destroy
      
      # Simulate job execution with deleted notification
      travel_to(start_time + 5.minutes) do
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(notification_id, cascade_config, 0)
        
        expect(result).to be_nil
      end
    end

    it "handles single-step cascades" do
      slack_target = double('SlackTarget')
      allow(slack_target).to receive(:to_optional_target_name).and_return(:slack)
      allow(slack_target).to receive(:notify).and_return(true)
      
      allow_any_instance_of(Comment).to receive(:optional_targets).and_return([slack_target])
      
      cascade_config = [
        { delay: 5.minutes, target: :slack }
      ]
      
      start_time = Time.current
      
      @notification.cascade_notify(cascade_config)
      
      # Simulate job execution
      travel_to(start_time + 5.minutes) do
        expect(slack_target).to receive(:notify).with(@notification, {})
        
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        job_instance = ActivityNotification::CascadingNotificationJob.new
        result = job_instance.perform(@notification.id, cascade_config, 0)
        
        expect(result).to eq({ slack: :success })
        
        # Verify no additional jobs were scheduled
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(0)
      end
    end
  end
end