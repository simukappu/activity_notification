describe ActivityNotification::CascadingNotificationJob, type: :job do
  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    
    @author_user = create(:confirmed_user)
    @user        = create(:confirmed_user)
    @article     = create(:article, user: @author_user)
    @comment     = create(:comment, article: @article, user: @user)
    @notification = @author_user.notifications.first
  end

  describe "#perform" do
    context "with a valid notification and cascade configuration" do
      before do
        # Mock optional targets
        allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(true)
      end

      it "does not trigger optional target if notification is opened" do
        @notification.open!
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        expect(result).to be_nil
      end

      it "returns nil if notification is not found" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(999999, cascade_config, 0)
        expect(result).to be_nil
      end

      it "returns nil if step_index is out of bounds" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 5)
        expect(result).to be_nil
      end

      it "schedules next step if available" do
        cascade_config = [
          { delay: 10.minutes, target: :slack },
          { delay: 10.minutes, target: :email }
        ]
        
        # Mock the optional target to avoid actual notification sending
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        allow(mock_optional_target).to receive(:notify).and_return(true)
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        expect {
          ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
          .with(@notification.id, cascade_config, 1)
          .on_queue(ActivityNotification.config.active_job_queue)
      end

      it "does not schedule next step if it's the last step" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        # Mock the optional target
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        allow(mock_optional_target).to receive(:notify).and_return(true)
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        expect {
          ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        }.not_to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
      end
    end

    context "with optional target handling" do
      before do
        allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(true)
      end

      it "returns :not_configured if optional target is not found" do
        cascade_config = [
          { delay: 10.minutes, target: :nonexistent }
        ]
        
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([])
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        expect(result).to eq({ nonexistent: :not_configured })
      end

      it "returns :not_subscribed if target is not subscribed" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(false)
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        expect(result).to eq({ slack: :not_subscribed })
      end

      it "returns :success when optional target is triggered successfully" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        allow(mock_optional_target).to receive(:notify).and_return(true)
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        expect(result).to eq({ slack: :success })
      end

      it "handles errors when optional target fails" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        allow(mock_optional_target).to receive(:notify).and_raise(StandardError.new("Connection failed"))
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        # With error rescue enabled (default)
        allow(ActivityNotification.config).to receive(:rescue_optional_target_errors).and_return(true)
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        expect(result[:slack]).to be_a(StandardError)
        expect(result[:slack].message).to eq("Connection failed")
      end

      it "raises error when optional target fails and rescue is disabled" do
        cascade_config = [
          { delay: 10.minutes, target: :slack }
        ]
        
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        allow(mock_optional_target).to receive(:notify).and_raise(StandardError.new("Connection failed"))
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        # With error rescue disabled
        allow(ActivityNotification.config).to receive(:rescue_optional_target_errors).and_return(false)
        
        expect {
          ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        }.to raise_error(StandardError, "Connection failed")
      end

      it "passes custom options to optional target" do
        cascade_config = [
          { delay: 10.minutes, target: :slack, options: { channel: '#alerts' } }
        ]
        
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        expect(mock_optional_target).to receive(:notify).with(@notification, { channel: '#alerts' }).and_return(true)
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
      end
    end

    context "with string keys in cascade configuration" do
      before do
        allow_any_instance_of(ActivityNotification::Notification).to receive(:optional_target_subscribed?).and_return(true)
      end

      it "handles string keys for target" do
        cascade_config = [
          { 'delay' => 10.minutes, 'target' => 'slack' }
        ]
        
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        allow(mock_optional_target).to receive(:notify).and_return(true)
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        result = ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
        expect(result).to eq({ slack: :success })
      end

      it "handles string keys for options" do
        cascade_config = [
          { 'delay' => 10.minutes, 'target' => 'slack', 'options' => { 'channel' => '#test' } }
        ]
        
        mock_optional_target = double('OptionalTarget')
        allow(mock_optional_target).to receive(:to_optional_target_name).and_return(:slack)
        expect(mock_optional_target).to receive(:notify).with(@notification, { 'channel' => '#test' }).and_return(true)
        allow_any_instance_of(Comment).to receive(:optional_targets).and_return([mock_optional_target])
        
        ActivityNotification::CascadingNotificationJob.new.perform(@notification.id, cascade_config, 0)
      end
    end
  end

  describe "integration with perform_later" do
    it "enqueues the job with correct parameters" do
      cascade_config = [
        { delay: 10.minutes, target: :slack }
      ]
      
      expect {
        ActivityNotification::CascadingNotificationJob.perform_later(@notification.id, cascade_config, 0)
      }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
        .with(@notification.id, cascade_config, 0)
        .on_queue(ActivityNotification.config.active_job_queue)
    end
  end
end
