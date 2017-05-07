describe ActivityNotification::Notification, type: :model do

  it_behaves_like :notification_api
  it_behaves_like :renderable

  describe "with association" do
    it "belongs to target" do
      target = create(:confirmed_user)
      notification = create(:notification, target: target)
      expect(notification.reload.target).to eq(target)
    end

    it "belongs to notifiable" do
      notifiable = create(:article)
      notification = create(:notification, notifiable: notifiable)
      expect(notification.reload.notifiable).to eq(notifiable)
    end

    it "belongs to group" do
      group = create(:article)
      notification = create(:notification, group: group)
      expect(notification.reload.group).to eq(group)
    end

    it "belongs to notification as group_owner" do
      group_owner  = create(:notification, group_owner: nil)
      group_member = create(:notification, group_owner: group_owner)
      expect(group_member.reload.group_owner.becomes(ActivityNotification::Notification)).to eq(group_owner)
    end

    it "has many notifications as group_members" do
      group_owner  = create(:notification, group_owner: nil)
      group_member = create(:notification, group_owner: group_owner)
      expect(group_owner.reload.group_members.first.becomes(ActivityNotification::Notification)).to eq(group_member)
    end

    it "belongs to notifier" do
      notifier = create(:confirmed_user)
      notification = create(:notification, notifier: notifier)
      expect(notification.reload.notifier).to eq(notifier)
    end
  end

  describe "with serializable column" do
    if ActivityNotification.config.orm == :active_record
      it "has parameters for hash with symbol" do
        parameters = {a: 1, b: 2, c: 3}
        notification = create(:notification, parameters: parameters)
        expect(notification.reload.parameters).to eq(parameters)
      end
    end

    it "has parameters for hash with string" do
      parameters = {'a' => 1, 'b' => 2, 'c' => 3}
      notification = create(:notification, parameters: parameters)
      expect(notification.reload.parameters).to eq(parameters)
    end
  end

  describe "with validation" do
    before { @notification = build(:notification) }

    it "is valid with target, notifiable and key" do
      expect(@notification).to be_valid
    end

    it "is invalid with blank target" do
      @notification.target = nil
      expect(@notification).to be_invalid
      expect(@notification.errors[:target].size).to eq(1)
    end

    it "is invalid with blank notifiable" do
      @notification.notifiable = nil
      expect(@notification).to be_invalid
      expect(@notification.errors[:notifiable].size).to eq(1)
    end

    it "is invalid with blank key" do
      @notification.key = nil
      expect(@notification).to be_invalid
      expect(@notification.errors[:key].size).to eq(1)
    end
  end

  describe "with scope" do
    context "to filter by notification status" do
      before do
        ActivityNotification::Notification.delete_all
        @unopened_group_owner  = create(:notification, group_owner: nil)
        @unopened_group_member = create(:notification, group_owner: @unopened_group_owner)
        @opened_group_owner    = create(:notification, group_owner: nil, opened_at: Time.current)
        @opened_group_member   = create(:notification, group_owner: @opened_group_owner, opened_at: Time.current)
      end

      it "works with group_owners_only scope" do
        notifications = ActivityNotification::Notification.group_owners_only
        expect(notifications.to_a.size).to eq(2)
        expect(notifications.unopened_only.first).to eq(@unopened_group_owner)
        expect(notifications.opened_only!.first).to eq(@opened_group_owner)
      end
  
      it "works with group_members_only scope" do
        notifications = ActivityNotification::Notification.group_members_only
        expect(notifications.to_a.size).to eq(2)
        expect(notifications.unopened_only.first).to eq(@unopened_group_member)
        expect(notifications.opened_only!.first).to eq(@opened_group_member)
      end
  
      it "works with unopened_only scope" do
        notifications = ActivityNotification::Notification.unopened_only
        expect(notifications.to_a.size).to eq(2)
        expect(notifications.group_owners_only.first).to eq(@unopened_group_owner)
        expect(notifications.group_members_only.first).to eq(@unopened_group_member)
      end
  
      it "works with unopened_index scope" do
        notifications = ActivityNotification::Notification.unopened_index
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@unopened_group_owner)
      end
  
      it "works with opened_only! scope" do
        notifications = ActivityNotification::Notification.opened_only!
        expect(notifications.to_a.size).to eq(2)
        expect(notifications.group_owners_only.first).to eq(@opened_group_owner)
        expect(notifications.group_members_only.first).to eq(@opened_group_member)
      end
  
      context "with opened_only scope" do
        it "works" do
          notifications = ActivityNotification::Notification.opened_only(4)
          expect(notifications.to_a.size).to eq(2)
          expect(notifications.group_owners_only.first).to eq(@opened_group_owner)
          expect(notifications.group_members_only.first).to eq(@opened_group_member)
        end
  
        it "works with limit" do
          notifications = ActivityNotification::Notification.opened_only(1)
          expect(notifications.to_a.size).to eq(1)
        end
      end
  
      context "with opened_index scope" do
        it "works" do
          notifications = ActivityNotification::Notification.opened_index(4)
          expect(notifications.to_a.size).to eq(1)
          expect(notifications.first).to eq(@opened_group_owner)
        end
    
        it "works with limit" do
          notifications = ActivityNotification::Notification.opened_index(0)
          expect(notifications.to_a.size).to eq(0)
        end
      end
  
      it "works with unopened_index_group_members_only scope" do
        notifications = ActivityNotification::Notification.unopened_index_group_members_only
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@unopened_group_member)
      end
  
      context "with opened_index_group_members_only scope" do
        it "works" do
          notifications = ActivityNotification::Notification.opened_index_group_members_only(4)
          expect(notifications.to_a.size).to eq(1)
          expect(notifications.first).to eq(@opened_group_member)
        end
    
        it "works with limit" do
          notifications = ActivityNotification::Notification.opened_index_group_members_only(0)
          expect(notifications.to_a.size).to eq(0)
        end
      end
    end

    context "to filter by association" do
      before do
        ActivityNotification::Notification.delete_all
        @target_1, @notifiable_1, @group_1, @key_1 = create(:confirmed_user), create(:article), nil,           "key.1"
        @target_2, @notifiable_2, @group_2, @key_2 = create(:confirmed_user), create(:comment), @notifiable_1, "key.2"
        @notification_1 = create(:notification, target: @target_1, notifiable: @notifiable_1, group: @group_1, key: @key_1)
        @notification_2 = create(:notification, target: @target_2, notifiable: @notifiable_2, group: @group_2, key: @key_2)
      end

      it "works with filtered_by_target scope" do
        notifications = ActivityNotification::Notification.filtered_by_target(@target_1)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_1)
        notifications = ActivityNotification::Notification.filtered_by_target(@target_2)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_2)
      end

      it "works with filtered_by_instance scope" do
        notifications = ActivityNotification::Notification.filtered_by_instance(@notifiable_1)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_1)
        notifications = ActivityNotification::Notification.filtered_by_instance(@notifiable_2)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_2)
      end

      it "works with filtered_by_type scope" do
        notifications = ActivityNotification::Notification.filtered_by_type(@notifiable_1.to_class_name)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_1)
        notifications = ActivityNotification::Notification.filtered_by_type(@notifiable_2.to_class_name)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_2)
      end

      it "works with filtered_by_group scope" do
        notifications = ActivityNotification::Notification.filtered_by_group(@group_1)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_1)
        notifications = ActivityNotification::Notification.filtered_by_group(@group_2)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_2)
      end

      it "works with filtered_by_key scope" do
        notifications = ActivityNotification::Notification.filtered_by_key(@key_1)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_1)
        notifications = ActivityNotification::Notification.filtered_by_key(@key_2)
        expect(notifications.to_a.size).to eq(1)
        expect(notifications.first).to eq(@notification_2)
      end

      describe 'filtered_by_options scope' do
        context 'with filtered_by_type options' do
          it "works with filtered_by_options scope" do
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_type: @notifiable_1.to_class_name })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_1)
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_type: @notifiable_2.to_class_name })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_2)
          end
        end
  
        context 'with filtered_by_group options' do
          it "works with filtered_by_options scope" do
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_group: @group_1 })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_1)
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_group: @group_2 })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_2)
          end
        end

        context 'with filtered_by_group_type and :filtered_by_group_id options' do
          it "works with filtered_by_options scope" do
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_group_type: 'Article', filtered_by_group_id: @group_2.id.to_s })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_2)
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_group_type: 'Article' })
            expect(notifications.to_a.size).to eq(2)
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_group_id: @group_2.id.to_s })
            expect(notifications.to_a.size).to eq(2)
          end
        end

        context 'with filtered_by_key options' do
          it "works with filtered_by_options scope" do
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_key: @key_1 })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_1)
            notifications = ActivityNotification::Notification.filtered_by_options({ filtered_by_key: @key_2 })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_2)
          end
        end

        context 'with custom_filter options' do
          it "works with filtered_by_options scope" do
            if ActivityNotification.config.orm == :active_record
              notifications = ActivityNotification::Notification.filtered_by_options({ custom_filter: ["notifications.key = ?", @key_1] })
              expect(notifications.to_a.size).to eq(1)
              expect(notifications.first).to eq(@notification_1)
            end

            notifications = ActivityNotification::Notification.filtered_by_options({ custom_filter: { key: @key_2 } })
            expect(notifications.to_a.size).to eq(1)
            expect(notifications.first).to eq(@notification_2)
          end
        end
  
        context 'with no options' do
          it "works with filtered_by_options scope" do
            notifications = ActivityNotification::Notification.filtered_by_options
            expect(notifications.to_a.size).to eq(2)
          end
        end
      end
    end

    context "to make order by created_at" do
      before do
        ActivityNotification::Notification.delete_all
        unopened_group_owner   = create(:notification, group_owner: nil)
        unopened_group_member  = create(:notification, group_owner: unopened_group_owner, created_at: unopened_group_owner.created_at + 10.second)
        opened_group_owner     = create(:notification, group_owner: nil, opened_at: Time.current, created_at: unopened_group_owner.created_at + 20.second)
        opened_group_member    = create(:notification, group_owner: opened_group_owner, opened_at: Time.current, created_at: unopened_group_owner.created_at + 30.second)
        @earliest_notification = unopened_group_owner
        @latest_notification   = opened_group_member
      end

      it "works with latest_order scope" do
        notifications = ActivityNotification::Notification.latest_order
        expect(notifications.to_a.size).to eq(4)
        expect(notifications.first).to eq(@latest_notification)
        expect(notifications.last).to eq(@earliest_notification)
      end

      it "works with earliest_order scope" do
        notifications = ActivityNotification::Notification.earliest_order
        expect(notifications.to_a.size).to eq(4)
        expect(notifications.first).to eq(@earliest_notification)
        expect(notifications.last).to eq(@latest_notification)
      end

      it "returns the latest notification with latest scope" do
        notification = ActivityNotification::Notification.latest
        expect(notification).to eq(@latest_notification)
      end

      it "returns the earliest notification with earliest scope" do
        notification = ActivityNotification::Notification.earliest
        expect(notification).to eq(@earliest_notification)
      end
    end
  end
end
