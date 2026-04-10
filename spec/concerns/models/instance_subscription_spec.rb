shared_examples_for :instance_subscription do
  include ActiveJob::TestHelper
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }
  let(:test_notifiable) { create(:article) }
  before do
    ActiveJob::Base.queue_adapter = :test
    ActivityNotification::Mailer.deliveries.clear
    described_class._notification_subscription_allowed = true
  end

  describe "instance-level subscriptions" do
    describe "#find_subscription with notifiable" do
      before do
        @test_key = 'test_key'
      end

      context "when an instance-level subscription exists" do
        it "returns the instance-level subscription" do
          subscription = test_instance.create_subscription(
            key: @test_key,
            notifiable_type: test_notifiable.class.name,
            notifiable_id: test_notifiable.id
          )
          found = test_instance.find_subscription(@test_key, notifiable: test_notifiable)
          expect(found).to eq(subscription)
        end
      end

      context "when only a key-level subscription exists" do
        it "returns nil for instance-level lookup" do
          test_instance.create_subscription(key: @test_key)
          found = test_instance.find_subscription(@test_key, notifiable: test_notifiable)
          expect(found).to be_nil
        end
      end

      context "when no subscription exists" do
        it "returns nil" do
          found = test_instance.find_subscription(@test_key, notifiable: test_notifiable)
          expect(found).to be_nil
        end
      end

      context "when both key-level and instance-level subscriptions exist" do
        it "returns the correct subscription for each lookup" do
          key_sub = test_instance.create_subscription(key: @test_key)
          instance_sub = test_instance.create_subscription(
            key: @test_key,
            notifiable_type: test_notifiable.class.name,
            notifiable_id: test_notifiable.id
          )
          expect(test_instance.find_subscription(@test_key)).to eq(key_sub)
          expect(test_instance.find_subscription(@test_key, notifiable: test_notifiable)).to eq(instance_sub)
        end
      end
    end

    describe "#create_subscription with notifiable" do
      before do
        @test_key = 'test_key'
      end

      it "creates an instance-level subscription" do
        subscription = test_instance.create_subscription(
          key: @test_key,
          notifiable_type: test_notifiable.class.name,
          notifiable_id: test_notifiable.id
        )
        expect(subscription).to be_persisted
        expect(subscription.subscribing?).to be_truthy
      end

      it "allows both key-level and instance-level subscriptions for the same key" do
        key_sub = test_instance.create_subscription(key: @test_key)
        instance_sub = test_instance.create_subscription(
          key: @test_key,
          notifiable_type: test_notifiable.class.name,
          notifiable_id: test_notifiable.id
        )
        expect(key_sub).to be_persisted
        expect(instance_sub).to be_persisted
        expect(test_instance.subscriptions.reload.count).to eq(2)
      end

      it "allows instance-level subscriptions for different notifiables with the same key" do
        other_notifiable = create(:article)
        sub1 = test_instance.create_subscription(
          key: @test_key,
          notifiable_type: test_notifiable.class.name,
          notifiable_id: test_notifiable.id
        )
        sub2 = test_instance.create_subscription(
          key: @test_key,
          notifiable_type: other_notifiable.class.name,
          notifiable_id: other_notifiable.id
        )
        expect(sub1).to be_persisted
        expect(sub2).to be_persisted
      end
    end

    describe "#find_or_create_subscription with notifiable" do
      before do
        @test_key = 'test_key'
      end

      context "when the instance-level subscription does not exist" do
        it "creates and returns a new instance-level subscription" do
          subscription = test_instance.find_or_create_subscription(@test_key, notifiable: test_notifiable)
          expect(subscription).to be_persisted
          expect(subscription.key).to eq(@test_key)
          expect(subscription.target).to eq(test_instance)
        end
      end

      context "when the instance-level subscription already exists" do
        it "returns the existing subscription" do
          existing = test_instance.create_subscription(
            key: @test_key,
            notifiable_type: test_notifiable.class.name,
            notifiable_id: test_notifiable.id
          )
          found = test_instance.find_or_create_subscription(@test_key, notifiable: test_notifiable)
          expect(found).to eq(existing)
        end
      end
    end

    describe "#subscribes_to_notification? with notifiable" do
      before do
        @test_key = 'test_key'
      end

      context "when unsubscribed at key-level but subscribed at instance-level" do
        before do
          test_instance.create_subscription(key: @test_key, subscribing: false)
          test_instance.create_subscription(
            key: @test_key,
            notifiable_type: test_notifiable.class.name,
            notifiable_id: test_notifiable.id
          )
        end

        it "returns false without notifiable (key-level check)" do
          expect(test_instance.subscribes_to_notification?(@test_key)).to be_falsey
        end

        it "returns true with notifiable (instance-level check)" do
          expect(test_instance.subscribes_to_notification?(@test_key, notifiable: test_notifiable)).to be_truthy
        end
      end

      context "when subscribed at key-level and no instance-level subscription" do
        before do
          test_instance.create_subscription(key: @test_key)
        end

        it "returns true without notifiable" do
          expect(test_instance.subscribes_to_notification?(@test_key)).to be_truthy
        end

        it "returns true with notifiable (falls back to key-level)" do
          expect(test_instance.subscribes_to_notification?(@test_key, notifiable: test_notifiable)).to be_truthy
        end
      end

      context "when no subscriptions exist" do
        context "with subscribe_as_default true" do
          it "returns true with notifiable" do
            subscribe_as_default = ActivityNotification.config.subscribe_as_default
            ActivityNotification.config.subscribe_as_default = true
            expect(test_instance.subscribes_to_notification?(@test_key, notifiable: test_notifiable)).to be_truthy
            ActivityNotification.config.subscribe_as_default = subscribe_as_default
          end
        end

        context "with subscribe_as_default false" do
          it "returns false without instance-level subscription" do
            subscribe_as_default = ActivityNotification.config.subscribe_as_default
            ActivityNotification.config.subscribe_as_default = false
            expect(test_instance.subscribes_to_notification?(@test_key, notifiable: test_notifiable)).to be_falsey
            ActivityNotification.config.subscribe_as_default = subscribe_as_default
          end

          it "returns true with active instance-level subscription" do
            subscribe_as_default = ActivityNotification.config.subscribe_as_default
            ActivityNotification.config.subscribe_as_default = false
            test_instance.create_subscription(
              key: @test_key,
              notifiable_type: test_notifiable.class.name,
              notifiable_id: test_notifiable.id
            )
            expect(test_instance.subscribes_to_notification?(@test_key, notifiable: test_notifiable)).to be_truthy
            ActivityNotification.config.subscribe_as_default = subscribe_as_default
          end
        end
      end

      context "when instance-level subscription is unsubscribed" do
        before do
          sub = test_instance.create_subscription(
            key: @test_key,
            notifiable_type: test_notifiable.class.name,
            notifiable_id: test_notifiable.id
          )
          sub.unsubscribe
        end

        it "does not grant access via instance subscription" do
          subscribe_as_default = ActivityNotification.config.subscribe_as_default
          ActivityNotification.config.subscribe_as_default = false
          expect(test_instance.subscribes_to_notification?(@test_key, notifiable: test_notifiable)).to be_falsey
          ActivityNotification.config.subscribe_as_default = subscribe_as_default
        end
      end
    end

    describe "notification generation with instance subscriptions" do
      before do
        @author_user = create(:confirmed_user)
        @user_1      = create(:confirmed_user)
        @user_2      = create(:confirmed_user)
        @article     = create(:article, user: @author_user)
        @comment     = create(:comment, article: @article, user: @user_1)
        @test_key    = 'comment.default'
      end

      context "when target has instance-level subscription for the notifiable" do
        it "generates notification even when unsubscribed at key-level" do
          # Unsubscribe at key-level
          @user_2.create_subscription(key: @test_key, subscribing: false)
          # Subscribe at instance-level for this specific comment
          @user_2.create_subscription(
            key: @test_key,
            notifiable_type: @comment.class.name,
            notifiable_id: @comment.id
          )
          notification = ActivityNotification::Notification.notify_to(@user_2, @comment)
          expect(notification).not_to be_nil
          expect(notification.target).to eq(@user_2)
        end
      end

      context "when target has no instance-level subscription and is unsubscribed at key-level" do
        it "does not generate notification" do
          @user_2.create_subscription(key: @test_key, subscribing: false)
          notification = ActivityNotification::Notification.notify_to(@user_2, @comment)
          expect(notification).to be_nil
        end
      end
    end

    describe "instance_subscription_targets" do
      before do
        @author_user = create(:confirmed_user)
        @user_1      = create(:confirmed_user)
        @user_2      = create(:confirmed_user)
        @user_3      = create(:confirmed_user)
        @article     = create(:article, user: @author_user)
        @comment     = create(:comment, article: @article, user: @user_1)
        @test_key    = 'comment.default'
      end

      it "returns targets with active instance-level subscriptions" do
        @user_2.create_subscription(
          key: @test_key,
          notifiable_type: @comment.class.name,
          notifiable_id: @comment.id
        )
        targets = @comment.instance_subscription_targets('User', @test_key)
        expect(targets).to include(@user_2)
        expect(targets).not_to include(@user_1)
        expect(targets).not_to include(@user_3)
      end

      it "does not return targets with unsubscribed instance-level subscriptions" do
        sub = @user_2.create_subscription(
          key: @test_key,
          notifiable_type: @comment.class.name,
          notifiable_id: @comment.id
        )
        sub.unsubscribe
        targets = @comment.instance_subscription_targets('User', @test_key)
        expect(targets).not_to include(@user_2)
      end

      it "does not return targets subscribed to a different notifiable" do
        other_comment = create(:comment, article: @article, user: @user_1)
        @user_2.create_subscription(
          key: @test_key,
          notifiable_type: other_comment.class.name,
          notifiable_id: other_comment.id
        )
        targets = @comment.instance_subscription_targets('User', @test_key)
        expect(targets).not_to include(@user_2)
      end

      it "returns multiple targets with instance-level subscriptions" do
        @user_2.create_subscription(
          key: @test_key,
          notifiable_type: @comment.class.name,
          notifiable_id: @comment.id
        )
        @user_3.create_subscription(
          key: @test_key,
          notifiable_type: @comment.class.name,
          notifiable_id: @comment.id
        )
        targets = @comment.instance_subscription_targets('User', @test_key)
        expect(targets).to include(@user_2)
        expect(targets).to include(@user_3)
        expect(targets.size).to eq(2)
      end
    end

    describe "notify with instance subscription targets deduplication" do
      before do
        @author_user = create(:confirmed_user)
        @user_1      = create(:confirmed_user)
        @article     = create(:article, user: @author_user)
        @comment     = create(:comment, article: @article, user: @author_user)
        @test_key    = 'comment.default'
      end

      it "does not create duplicate notifications when target is in both notification_targets and instance subscriptions" do
        # user_1 is already in notification_targets (via acts_as_notifiable config)
        # Also create an instance-level subscription for user_1
        @user_1.create_subscription(
          key: @test_key,
          notifiable_type: @comment.class.name,
          notifiable_id: @comment.id
        )
        notifications = ActivityNotification::Notification.notify(:users, @comment)
        user_1_notifications = notifications.select { |n| n.target == @user_1 }
        expect(user_1_notifications.size).to be <= 1
      end
    end
  end
end
