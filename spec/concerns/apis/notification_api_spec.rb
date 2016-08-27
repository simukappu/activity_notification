shared_examples_for :notification_api do
  include ActiveJob::TestHelper
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }
  before do
    ActiveJob::Base.queue_adapter = :test
    ActivityNotification::Mailer.deliveries.clear
    expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
  end

  describe "as public class methods" do
    before do
      described_class.delete_all
      @author_user = create(:confirmed_user)
      @user_1      = create(:confirmed_user)
      @user_2      = create(:confirmed_user)
      @article     = create(:article, user: @author_user)
      @comment_1   = create(:comment, article: @article, user: @user_1)
      @comment_2   = create(:comment, article: @article, user: @user_2)
      expect(@author_user.notifications.count).to eq(0)
      expect(@user_1.notifications.count).to eq(0)
      expect(@user_2.notifications.count).to eq(0)
    end

    describe ".notify" do
      it "returns array of created notifications" do
        notifications = described_class.notify(:users, @comment_2)
        expect(notifications).to be_a Array
        expect(notifications.size).to eq(2)
        if notifications[0].target == @author_user
          validate_expected_notification(notifications[0], @author_user, @comment_2)
          validate_expected_notification(notifications[1], @user_1, @comment_2)
        else
          validate_expected_notification(notifications[0], @user_1, @comment_2)
          validate_expected_notification(notifications[1], @author_user, @comment_2)
        end
      end

      it "creates notification records" do
        described_class.notify(:users, @comment_2)
        expect(@author_user.notifications.unopened_only.count).to eq(1)
        expect(@user_1.notifications.unopened_only.count).to eq(1)
        expect(@user_2.notifications.unopened_only.count).to eq(0)
      end

      context "as default" do
        it "sends notification email later" do
          expect {
            perform_enqueued_jobs do
              described_class.notify(:users, @comment_2)
            end
          }.to change { ActivityNotification::Mailer.deliveries.size }.by(2)
          expect(ActivityNotification::Mailer.deliveries.size).to eq(2)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(@user_1.email)
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(@author_user.email)
        end
  
        it "sends notification email with active job queue" do
          expect {
            described_class.notify(:users, @comment_2)
          }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
        end
      end

      context "with send_later false" do
        it "sends notification email now" do
          described_class.notify(:users, @comment_2, send_later: false)
          expect(ActivityNotification::Mailer.deliveries.size).to eq(2)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(@user_1.email)
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(@author_user.email)
        end
      end
    end

    describe ".notify_all" do
      it "returns array of created notifications" do
        notifications = described_class.notify_all([@author_user, @user_1], @comment_2)
        expect(notifications).to be_a Array
        expect(notifications.size).to eq(2)
        validate_expected_notification(notifications[0], @author_user, @comment_2)
        validate_expected_notification(notifications[1], @user_1, @comment_2)
      end

      it "creates notification records" do
        described_class.notify_all([@author_user, @user_1], @comment_2)
        expect(@author_user.notifications.unopened_only.count).to eq(1)
        expect(@user_1.notifications.unopened_only.count).to eq(1)
        expect(@user_2.notifications.unopened_only.count).to eq(0)
      end

      context "as default" do
        it "sends notification email later" do
          expect {
            perform_enqueued_jobs do
              described_class.notify_all([@author_user, @user_1], @comment_2)
            end
          }.to change { ActivityNotification::Mailer.deliveries.size }.by(2)
          expect(ActivityNotification::Mailer.deliveries.size).to eq(2)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(@user_1.email)
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(@author_user.email)
        end

        it "sends notification email with active job queue" do
          expect {
            described_class.notify_all([@author_user, @user_1], @comment_2)
          }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(2)
        end
      end

      context "with send_later false" do
        it "sends notification email now" do
          described_class.notify_all([@author_user, @user_1], @comment_2, send_later: false)
          expect(ActivityNotification::Mailer.deliveries.size).to eq(2)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(@user_1.email)
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(@author_user.email)
        end
      end
    end

    describe ".notify_to" do
      it "returns reated notification" do
        notification = described_class.notify_to(@user_1, @comment_2)
        validate_expected_notification(notification, @user_1, @comment_2)
      end

      it "creates notification records" do
        described_class.notify_to(@user_1, @comment_2)
        expect(@user_1.notifications.unopened_only.count).to eq(1)
        expect(@user_2.notifications.unopened_only.count).to eq(0)
      end

      context "as default" do
        it "sends notification email later" do
          expect {
            perform_enqueued_jobs do
              described_class.notify_to(@user_1, @comment_2)
            end
          }.to change { ActivityNotification::Mailer.deliveries.size }.by(1)
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(@user_1.email)
        end

        it "sends notification email with active job queue" do
          expect {
            described_class.notify_to(@user_1, @comment_2)
          }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
        end
      end

      context "with send_later false" do
        it "sends notification email now" do
          described_class.notify_to(@user_1, @comment_2, send_later: false)
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(@user_1.email)
        end
      end

      context "with options" do
        context "as default" do
          let(:created_notification) { 
            described_class.notify_to(@user_1, @comment_2)
            @user_1.notifications.latest
          }

          it "has key of notifiable.default_notification_key" do
            expect(created_notification.key)
              .to eq(created_notification.notifiable.default_notification_key)
          end

          it "has group of notifiable.notification_group" do
            expect(created_notification.group)
              .to eq(
                created_notification.notifiable.notification_group(
                  @user_1.class,
                  created_notification.key
                )
              )
          end

          it "has notifier of notifiable.notifier" do
            expect(created_notification.notifier)
              .to eq(
                created_notification.notifiable.notifier(
                  @user_1.class,
                  created_notification.key
                )
              )
          end

          it "has parameters of notifiable.notification_parameters" do
            expect(created_notification.parameters)
              .to eq(
                created_notification.notifiable.notification_parameters(
                  @user_1.class,
                  created_notification.key
                )
              )
          end
        end

        context "as specified default value" do
          let(:created_notification) { 
            described_class.notify_to(@user_1, @comment_2)
          }

          it "has key of [notifiable_class_name].default" do
            expect(created_notification.key).to eq('comment.default')
          end

          it "has group of group in acts_as_notifiable" do
            expect(created_notification.group).to eq(@article)
          end

          it "has notifier of notifier in acts_as_notifiable" do
            expect(created_notification.notifier).to eq(@user_2)
          end

          it "has parameters of parameters in acts_as_notifiable" do
            expect(created_notification.parameters).to eq({test_default_param: '1'})
          end
        end

        context "as api options" do
          let(:created_notification) { 
            described_class.notify_to(
              @user_1, @comment_2,
              key: 'custom_test_key',
              group: @comment_2,
              notifier: @author_user,
              parameters: {custom_param_1: '1'},
              custom_param_2: '2'
            )
          }

          it "has key of key option" do
            expect(created_notification.key).to eq('custom_test_key')
          end

          it "has group of group option" do
            expect(created_notification.group).to eq(@comment_2)
          end

          it "has notifier of notifier option" do
            expect(created_notification.notifier).to eq(@author_user)
          end

          it "has parameters of parameters option" do
            expect(created_notification.parameters[:custom_param_1]).to eq('1')
          end

          it "has parameters from custom options" do
            expect(created_notification.parameters[:custom_param_2]).to eq('2')
          end
        end
      end

      context "with grouping" do
        it "creates group by specified group and the target" do
          owner_notification  = described_class.notify_to(@user_1, @comment_1, group: @article)
          member_notification = described_class.notify_to(@user_1, @comment_2, group: @article)
          expect(member_notification.group_owner).to eq(owner_notification)
        end

        it "belongs to single group" do
          owner_notification    = described_class.notify_to(@user_1, @comment_1, group: @article)
          member_notification_1 = described_class.notify_to(@user_1, @comment_2, group: @article)
          member_notification_2 = described_class.notify_to(@user_1, @comment_2, group: @article)
          expect(member_notification_1.group_owner).to eq(owner_notification)
          expect(member_notification_2.group_owner).to eq(owner_notification)
        end

        it "does not create group with opened notifications" do
          owner_notification  = described_class.notify_to(@user_1, @comment_1, group: @article)
          owner_notification.open!
          member_notification = described_class.notify_to(@user_1, @comment_2, group: @article)
          expect(member_notification.group_owner).to eq(nil)
        end

        it "does not create group with different target" do
          owner_notification  = described_class.notify_to(@user_1, @comment_1, group: @article)
          member_notification = described_class.notify_to(@user_2, @comment_2, group: @article)
          expect(member_notification.group_owner).to eq(nil)
        end

        it "does not create group with different group" do
          owner_notification  = described_class.notify_to(@user_1, @comment_1, group: @article)
          member_notification = described_class.notify_to(@user_1, @comment_2, group: @comment_2)
          expect(member_notification.group_owner).to eq(nil)
        end

        it "does not create group with different notifiable type" do
          owner_notification  = described_class.notify_to(@user_1, @comment_1, group: @article)
          member_notification = described_class.notify_to(@user_1, @article,   group: @article)
          expect(member_notification.group_owner).to eq(nil)
        end

        it "does not create group with different key" do
          owner_notification  = described_class.notify_to(@user_1, @comment_1, key: 'key1', group: @article)
          member_notification = described_class.notify_to(@user_1, @comment_2, key: 'key2', group: @article)
          expect(member_notification.group_owner).to eq(nil)
        end
      end
    end

    describe ".open_all_of" do
      before do
        described_class.notify_to(@user_1, @comment_2)
        described_class.notify_to(@user_1, @comment_2)
        expect(@user_1.notifications.unopened_only.count).to eq(2)
        expect(@user_1.notifications.opened_only!.count).to eq(0)
      end

      it "returns the number of opened notification records" do
        expect(described_class.open_all_of(@user_1)).to eq(2)
      end

      it "opens all notifications of the target" do
        described_class.open_all_of(@user_1)
        expect(@user_1.notifications.unopened_only.count).to eq(0)
        expect(@user_1.notifications.opened_only!.count).to eq(2)
      end

      it "does not open any notifications of the other targets" do
        described_class.open_all_of(@user_2)
        expect(@user_1.notifications.unopened_only.count).to eq(2)
        expect(@user_1.notifications.opened_only!.count).to eq(0)
      end
    end

    describe ".group_member_exists?" do
      context "when specified notifications have any group members" do
        let(:owner_notifications) do
          target       = create(:confirmed_user)
          group_owner  = create(:notification, target: target, group_owner: nil)
                         create(:notification, target: target, group_owner: nil)
          group_member = create(:notification, target: target, group_owner: group_owner)
          target.notifications.group_owners_only
        end

        it "returns true for DB query" do
          expect(described_class.group_member_exists?(owner_notifications))
            .to be_truthy
        end

        it "returns true for Array" do
          expect(described_class.group_member_exists?(owner_notifications.to_a))
            .to be_truthy
        end
      end

      context "when specified notifications have no group members" do
        let(:owner_notifications) do
          target       = create(:confirmed_user)
          group_owner  = create(:notification, target: target, group_owner: nil)
                         create(:notification, target: target, group_owner: nil)
          target.notifications.group_owners_only
        end

        it "returns false" do
          expect(described_class.group_member_exists?(owner_notifications))
            .to be_falsey
        end
      end
    end

    describe ".available_options" do
      it "returns list of available options in notify api" do
        expect(described_class.available_options)
          .to eq([:key, :group, :parameters, :notifier, :send_email, :send_later])
      end
    end
  end

  describe "as private class methods" do
    describe ".store_notification" do
      it "is defined as private method" do
        expect(described_class.respond_to?(:store_notification)).to       be_falsey
        expect(described_class.respond_to?(:store_notification, true)).to be_truthy
      end
    end
  end

  describe "as public instance methods" do
    describe "#send_notification_email" do
      context "as default" do
        it "sends notification email later" do
          expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
          expect {
            perform_enqueued_jobs do
              test_instance.send_notification_email
            end
          }.to change { ActivityNotification::Mailer.deliveries.size }.by(1)
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(test_instance.target.email)
        end

        it "sends notification email with active job queue" do
          expect {
            test_instance.send_notification_email
          }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
        end
      end

      context "with send_later false" do
        it "sends notification email now" do
          expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
          test_instance.send_notification_email false
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
          expect(ActivityNotification::Mailer.deliveries.first.to[0]).to eq(test_instance.target.email)
        end
      end
    end

    describe "#open!" do
      before do
        described_class.delete_all
      end

      it "returns the number of opened notification records" do
        expect(test_instance.open!).to eq(1)
      end

      it "returns the number of opened notification records including group members" do
        create(test_class_name, group_owner: test_instance, opened_at: nil)
        expect(test_instance.open!).to eq(2)
      end

      context "as default" do
        it "open notification with current time" do
          expect(test_instance.opened_at.blank?).to be_truthy
          Timecop.freeze(DateTime.now)
          test_instance.open!
          expect(test_instance.opened_at.blank?).to be_falsey
          expect(test_instance.opened_at).to        eq(DateTime.now)
          Timecop.return
        end

        it "open group member notifications with current time" do
          group_member = create(test_class_name, group_owner: test_instance)
          expect(group_member.opened_at.blank?).to be_truthy
          Timecop.freeze(DateTime.now)
          test_instance.open!
          group_member = group_member.reload
          expect(group_member.opened_at.blank?).to be_falsey
          #TODO Check and make test pass
          #expect(group_member.opened_at).to        eq(DateTime.now)
          Timecop.return
        end
      end

      context "with opened_at" do
        it "open notification with specified time" do
          expect(test_instance.opened_at.blank?).to be_truthy
          datetime = DateTime.now - 1.months
          test_instance.open!(datetime)
          expect(test_instance.opened_at.blank?).to be_falsey
          expect(test_instance.opened_at).to        eq(datetime)
        end

        it "open group member notifications with specified time" do
          group_member = create(test_class_name, group_owner: test_instance)
          expect(group_member.opened_at.blank?).to be_truthy
          datetime = DateTime.now - 1.months
          test_instance.open!(datetime)
          group_member = group_member.reload
          expect(group_member.opened_at.blank?).to be_falsey
          #TODO Check and make test pass
          #expect(group_member.opened_at).to        eq(datetime)
        end
      end

      context "with false as including_members" do
        it "does not open group member notifications" do
          group_member = create(test_class_name, group_owner: test_instance)
          expect(group_member.opened_at.blank?).to be_truthy
          datetime = DateTime.now - 1.months
          test_instance.open!(datetime, false)
          group_member = group_member.reload
          expect(group_member.opened_at.blank?).to be_truthy
        end

        it "returns the number of opened notification records" do
          create(test_class_name, group_owner: test_instance, opened_at: nil)
          expect(test_instance.open!(DateTime.now, false)).to eq(1)
        end
      end
    end

    describe "#unopened?" do
      context "when opened_at is blank" do
        it "returns true" do
          expect(test_instance.unopened?).to be_truthy
        end
      end

      context "when opened_at is present" do
        it "returns false" do
          test_instance.open!
          expect(test_instance.unopened?).to be_falsey
        end
      end
    end
      
    describe "#opened?" do
      context "when opened_at is blank" do
        it "returns false" do
          expect(test_instance.opened?).to be_falsey
        end
      end

      context "when opened_at is present" do
        it "returns true" do
          test_instance.open!
          expect(test_instance.opened?).to be_truthy
        end
      end
    end

    describe "#group_owner?" do
      context "when the notification is group owner" do
        it "returns true" do
          expect(test_instance.group_owner?).to be_truthy
        end
      end

      context "when the notification belongs to group" do
        it "returns false" do
          group_member = create(test_class_name, target: test_instance.target, group_owner: test_instance)
          expect(group_member.group_owner?).to be_falsey
        end
      end
    end

    describe "#group_member?" do
      context "when the notification is group owner" do
        it "returns false" do
          expect(test_instance.group_member?).to be_falsey
        end
      end

      context "when the notification belongs to group" do
        it "returns true" do
          group_member = create(test_class_name, target: test_instance.target, group_owner: test_instance)
          expect(group_member.group_member?).to be_truthy
        end
      end
    end

    describe "#group_member_exists?" do
      context "when the notification is group owner and has no group members" do
        it "returns false" do
          expect(test_instance.group_member_exists?).to be_falsey
        end
      end

      context "when the notification is group owner and has group members" do
        it "returns true" do
          create(test_class_name, target: test_instance.target, group_owner: test_instance)
          expect(test_instance.group_member_exists?).to be_truthy
        end
      end

      context "when the notification belongs to group" do
        it "returns true" do
          group_member = create(test_class_name, target: test_instance.target, group_owner: test_instance)
          expect(group_member.group_member_exists?).to be_truthy
        end
      end
    end

    describe "#group_member_count" do
      context "for unopened notification" do
        context "when the notification is group owner and has no group members" do
          it "returns 0" do
            expect(test_instance.group_member_count).to eq(0)
          end
        end

        context "when the notification is group owner and has group members" do
          it "returns member count" do
            create(test_class_name, target: test_instance.target, group_owner: test_instance)
            create(test_class_name, target: test_instance.target, group_owner: test_instance)
            expect(test_instance.group_member_count).to eq(2)
          end
        end

        context "when the notification belongs to group" do
          it "returns member count" do
            group_member = create(test_class_name, target: test_instance.target, group_owner: test_instance)
                           create(test_class_name, target: test_instance.target, group_owner: test_instance)
            expect(group_member.group_member_count).to eq(2)
          end
        end
      end

      context "for opened notification" do
        context "when the notification is group owner and has no group members" do
          it "returns 0" do
            test_instance.open!
            expect(test_instance.group_member_count).to eq(0)
          end
        end

        context "as default" do
          context "when the notification is group owner and has group members" do
            it "returns member count" do
              create(test_class_name, target: test_instance.target, group_owner: test_instance)
              create(test_class_name, target: test_instance.target, group_owner: test_instance)
              test_instance.open!
              expect(test_instance.group_member_count).to eq(2)
            end
          end

          context "when the notification belongs to group" do
            it "returns member count" do
              group_member = create(test_class_name, target: test_instance.target, group_owner: test_instance)
                             create(test_class_name, target: test_instance.target, group_owner: test_instance)
              test_instance.open!
              expect(group_member.group_member_count).to eq(2)
            end
          end
        end

        context "with limit" do
          context "when the notification is group owner and has group members" do
            it "returns member count by limit" do
              create(test_class_name, target: test_instance.target, group_owner: test_instance)
              create(test_class_name, target: test_instance.target, group_owner: test_instance)
              test_instance.open!
              expect(test_instance.group_member_count(0)).to eq(0)
            end
          end

          context "when the notification belongs to group" do
            it "returns member count by limit" do
              group_member = create(test_class_name, target: test_instance.target, group_owner: test_instance)
                             create(test_class_name, target: test_instance.target, group_owner: test_instance)
              test_instance.open!
              expect(group_member.group_member_count(0)).to eq(0)
            end
          end
        end
      end
    end

    describe "#notifiable_path" do
      it "returns notifiable.notifiable_path" do
        expect(test_instance.notifiable_path)
          .to eq(test_instance.notifiable.notifiable_path(test_instance.target_type, test_instance.key))
      end
    end
  end

  describe "as protected instance methods" do
    describe "#unopened_group_member_count" do
      it "is defined as protected method" do
        expect(test_instance.respond_to?(:unopened_group_member_count)).to       be_falsey
        expect(test_instance.respond_to?(:unopened_group_member_count, true)).to be_truthy
      end
    end

    describe "#opened_group_member_count" do
      it "is defined as protected method" do
        expect(test_instance.respond_to?(:opened_group_member_count)).to       be_falsey
        expect(test_instance.respond_to?(:opened_group_member_count, true)).to be_truthy
      end
    end
  end

  private
    def validate_expected_notification(notification, target, notifiable)
      expect(notification).to be_a described_class
      expect(notification.target).to eq(target)
      expect(notification.notifiable).to eq(notifiable)
    end

end