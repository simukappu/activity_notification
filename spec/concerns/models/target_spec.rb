shared_examples_for :target do
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }
  let(:test_notifiable) { create(:dummy_notifiable) }

  describe "with association" do
    it "has many notifications" do
      notification_1 = create(:notification, target: test_instance)
      notification_2 = create(:notification, target: test_instance)
      expect(test_instance.notifications.count).to    eq(2)
      expect(test_instance.notifications.earliest).to eq(notification_1)
      expect(test_instance.notifications.latest).to   eq(notification_2)
      expect(test_instance.notifications).to          eq (ActivityNotification::Notification.filtered_by_target(test_instance))
    end
  end    

  describe "as public class methods" do
    describe ".available_as_target?" do
      it "returns true" do
        expect(described_class.available_as_target?).to be_truthy
      end
    end

    describe ".set_target_class_defaults" do
      it "set parameter fields as default" do
        described_class.set_target_class_defaults
        expect(described_class._notification_email).to                 eq(nil)
        expect(described_class._notification_email_allowed).to         eq(ActivityNotification.config.email_enabled)
        expect(described_class._notification_devise_resource).to       be_a_kind_of(Proc)
        expect(described_class._printable_notification_target_name).to eq(:printable_name)
      end
    end    
  end

  describe "as public instance methods" do
    before do
      ActivityNotification::Notification.delete_all
      described_class.set_target_class_defaults
    end

    describe "#mailer_to" do
      context "without any configuration" do
        it "returns nil" do
          expect(test_instance.mailer_to).to be_nil
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notification_email = 'test@example.com'
          expect(test_instance.mailer_to).to eq('test@example.com')
        end

        it "returns specified symbol of field" do
          described_class._notification_email = :email
          expect(test_instance.mailer_to).to eq(test_instance.email)
        end

        it "returns specified symbol of method" do
          module AdditionalMethods
            def custom_notification_email
              'test@example.com'
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_email = :custom_notification_email
          expect(test_instance.mailer_to).to eq('test@example.com')
        end

        it "returns specified lambda with single target argument" do
          described_class._notification_email = ->(target){ 'test@example.com' }
          expect(test_instance.mailer_to).to eq('test@example.com')
        end
      end
    end

    describe "#notification_email_allowed?" do
      context "without any configuration" do
        it "returns ActivityNotification.config.email_enabled" do
          expect(test_instance.notification_email_allowed?(test_notifiable, 'dummy_key'))
            .to eq(ActivityNotification.config.email_enabled)
        end

        it "returns false as default" do
          expect(test_instance.notification_email_allowed?(test_notifiable, 'dummy_key')).to be_falsey
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notification_email_allowed = true
          expect(test_instance.notification_email_allowed?(test_notifiable, 'dummy_key')).to eq(true)
        end

        it "returns specified symbol without argument" do
          module AdditionalMethods
            def custom_notification_email_allowed?
              true
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_email_allowed = :custom_notification_email_allowed?
          expect(test_instance.notification_email_allowed?(test_notifiable, 'dummy_key')).to eq(true)
        end

        it "returns specified symbol with target and key arguments" do
          module AdditionalMethods
            def custom_notification_email_allowed?(notifiable, key)
              true
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_email_allowed = :custom_notification_email_allowed?
          expect(test_instance.notification_email_allowed?(test_notifiable, 'dummy_key')).to eq(true)
        end

        it "returns specified lambda with single target argument" do
          described_class._notification_email_allowed = ->(target){ true }
          expect(test_instance.notification_email_allowed?(test_notifiable, 'dummy_key')).to eq(true)
        end

        it "returns specified lambda with target, notifiable and key arguments" do
          described_class._notification_email_allowed = ->(target, notifiable, key){ true }
          expect(test_instance.notification_email_allowed?(test_notifiable, 'dummy_key')).to eq(true)
        end
      end
    end

    describe "#authenticated_with_devise?" do
      context "without any configuration" do
        context "when the current devise resource and called target are defferent class instance" do
          it "raises TypeError" do
            expect { test_instance.authenticated_with_devise?(test_notifiable) }
              .to raise_error(TypeError, /Defferent type of .+ has been passed to .+ You have to override .+ /)
          end
        end
  
        context "when the current devise resource equals called target" do
          it "returns true" do
            expect(test_instance.authenticated_with_devise?(test_instance)).to be_truthy
          end
        end
  
        context "when the current devise resource does not equal called target" do
          it "returns false" do
            expect(test_instance.authenticated_with_devise?(create(test_class_name))).to be_falsey
          end
        end
      end

      context "configured with a field" do
        context "when the current devise resource and called target are defferent class instance" do
          it "raises TypeError" do
            described_class._notification_devise_resource = test_notifiable
            expect { test_instance.authenticated_with_devise?(test_instance) }
              .to raise_error(TypeError, /Defferent type of .+ has been passed to .+ You have to override .+ /)
          end
        end
  
        context "when the current devise resource equals called target" do
          it "returns true" do
            described_class._notification_devise_resource = test_notifiable
            expect(test_instance.authenticated_with_devise?(test_notifiable)).to be_truthy
          end
        end
  
        context "when the current devise resource does not equal called target" do
          it "returns false" do
            described_class._notification_devise_resource = test_instance
            expect(test_instance.authenticated_with_devise?(create(test_class_name))).to be_falsey
          end
        end
      end
    end

    describe "#printable_target_name" do
      context "without any configuration" do
        it "returns ActivityNotification::Common.printable_name" do
          expect(test_instance.printable_target_name).to eq(test_instance.printable_name)
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._printable_notification_target_name = 'test_printable_name'
          expect(test_instance.printable_target_name).to eq('test_printable_name')
        end

        it "returns specified symbol of field" do
          described_class._printable_notification_target_name = :name
          expect(test_instance.printable_target_name).to eq(test_instance.name)
        end

        it "returns specified symbol of method" do
          module AdditionalMethods
            def custom_printable_name
              'test_printable_name'
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._printable_notification_target_name = :custom_printable_name
          expect(test_instance.printable_target_name).to eq('test_printable_name')
        end

        it "returns specified lambda with single target argument" do
          described_class._printable_notification_target_name = ->(target){ 'test_printable_name' }
          expect(test_instance.printable_target_name).to eq('test_printable_name')
        end
      end
    end

    describe "#unopened_notification_count" do
      it "returns count of unopened notification index" do
        create(:notification, target: test_instance)
        create(:notification, target: test_instance)
        expect(test_instance.unopened_notification_count).to eq(2)
      end

      it "returns count of unopened notification index (owner only)" do
        group_owner  = create(:notification, target: test_instance, group_owner: nil)
                       create(:notification, target: test_instance, group_owner: nil)
        group_member = create(:notification, target: test_instance, group_owner: group_owner)
        expect(test_instance.unopened_notification_count).to eq(2)
      end
    end

    describe "#has_unopened_notifications?" do
      context "when the target has no unopened notifications" do
        it "returns false" do
          expect(test_instance.has_unopened_notifications?).to be_falsey
        end
      end

      context "when the target has unopened notifications" do
        it "returns true" do
          create(:notification, target: test_instance)
          expect(test_instance.has_unopened_notifications?).to be_truthy
        end
      end
    end

    describe "#notification_index" do
      context "when the target has no notifications" do
        it "returns empty records" do
          expect(test_instance.notification_index).to be_empty
        end
      end

      context "when the target has unopened notifications" do
        before do
          @notifiable = create(:article)
          @group = create(:article)
          @key = 'test.key.1'
          create(:notification, target: test_instance, notifiable: @notifiable)
          create(:notification, target: test_instance, notifiable: create(:comment), group: @group)
          create(:notification, target: test_instance, notifiable: create(:article), key: @key).open!
        end

        it "calls unopened_notification_index" do
          expect(test_instance).to receive(:unopened_notification_index).at_least(:once)
          test_instance.notification_index
        end

        context "without limit" do
          it "returns the combined array of unopened_notification_index and opened_notification_index" do
            expect(test_instance.notification_index[0]).to eq(test_instance.unopened_notification_index[0])
            expect(test_instance.notification_index[1]).to eq(test_instance.unopened_notification_index[1])
            expect(test_instance.notification_index[2]).to eq(test_instance.opened_notification_index[0])
            expect(test_instance.notification_index.size).to eq(3)
          end
        end

        context "with limit" do
          it "returns the same as unopened_notification_index with limit" do
            options = { limit: 1 }
            expect(test_instance.notification_index(options)).to eq(test_instance.unopened_notification_index(options))
            expect(test_instance.notification_index(options).size).to eq(1)
          end
        end

        context "without limit" do
          it "returns the combined array of unopened_notification_index and opened_notification_index" do
            expect(test_instance.notification_index[0]).to eq(test_instance.unopened_notification_index[0])
            expect(test_instance.notification_index[1]).to eq(test_instance.unopened_notification_index[1])
            expect(test_instance.notification_index[2]).to eq(test_instance.opened_notification_index[0])
            expect(test_instance.notification_index.size).to eq(3)
          end
        end

        context "with reverse" do
          it "returns the earliest order" do
            options = { reverse: true }
            expect(test_instance.notification_index(options)[0]).to eq(test_instance.notification_index[1])
            expect(test_instance.notification_index(options)[1]).to eq(test_instance.notification_index[0])
            expect(test_instance.notification_index(options)[2]).to eq(test_instance.notification_index[2])
            expect(test_instance.notification_index(options).size).to eq(3)
          end
        end

        context 'with filtered_by_type options' do
          it "returns filtered notifications only" do
            options = { filtered_by_type: 'Article' }
            expect(test_instance.notification_index(options).size).to eq(2)
            options = { filtered_by_type: 'Comment' }
            expect(test_instance.notification_index(options).size).to eq(1)
          end
        end

        context 'with filtered_by_group options' do
          it "returns filtered notifications only" do
            options = { filtered_by_group: @group }
            expect(test_instance.notification_index(options).size).to eq(1)
          end
        end

        context 'with filtered_by_group_type and :filtered_by_group_id options' do
          it "returns filtered notifications only" do
            options = { filtered_by_group_type: 'Article', filtered_by_group_id: @group.id.to_s }
            expect(test_instance.notification_index(options).size).to eq(1)
          end
        end

        context 'with filtered_by_key options' do
          it "returns filtered notifications only" do
            options = { filtered_by_key: @key }
            expect(test_instance.notification_index(options).size).to eq(1)
          end
        end
      end

      context "when the target has no unopened notifications" do
        before do
          create(:notification, target: test_instance, opened_at: DateTime.now)
          create(:notification, target: test_instance, opened_at: DateTime.now)
        end

        it "calls unopened_notification_index" do
          expect(test_instance).to receive(:opened_notification_index).at_least(:once)
          test_instance.notification_index
        end

        context "without limit" do
          it "returns the same as opened_notification_index" do
            expect(test_instance.notification_index).to eq(test_instance.opened_notification_index)
            expect(test_instance.notification_index.size).to eq(2)
          end
        end

        context "with limit" do
          it "returns the same as opened_notification_index with limit" do
            options = { limit: 1 }
            expect(test_instance.notification_index(options)).to eq(test_instance.opened_notification_index(options))
            expect(test_instance.notification_index(options).size).to eq(1)
          end
        end
      end
    end

    describe "#unopened_notification_index" do
      context "when the target has no notifications" do
        it "returns empty records" do
          expect(test_instance.unopened_notification_index).to be_empty
        end
      end

      context "when the target has unopened notifications" do
        before do
          @notification_1 = create(:notification, target: test_instance)
          @notification_2 = create(:notification, target: test_instance)
        end

        context "without limit" do
          it "returns unopened notification index" do
            expect(test_instance.unopened_notification_index.size).to eq(2)
            expect(test_instance.unopened_notification_index.last).to  eq(@notification_1)
            expect(test_instance.unopened_notification_index.first).to eq(@notification_2)
          end

          it "returns unopened notification index (owner only)" do
            group_member   = create(:notification, target: test_instance, group_owner: @notification_1)
            expect(test_instance.unopened_notification_index.size).to eq(2)
            expect(test_instance.unopened_notification_index.last).to  eq(@notification_1)
            expect(test_instance.unopened_notification_index.first).to eq(@notification_2)
          end

          it "returns unopened notification index (unopened only)" do
            notification_3 = create(:notification, target: test_instance, opened_at: DateTime.now)
            expect(test_instance.unopened_notification_index.size).to eq(2)
            expect(test_instance.unopened_notification_index.last).to  eq(@notification_1)
            expect(test_instance.unopened_notification_index.first).to eq(@notification_2)
          end
        end

        context "with limit" do
          it "returns unopened notification index with limit" do
            options = { limit: 1 }
            expect(test_instance.unopened_notification_index(options).size).to eq(1)
            expect(test_instance.unopened_notification_index(options).first).to eq(@notification_2)
          end
        end
      end

      context "when the target has no unopened notifications" do
        before do
          create(:notification, target: test_instance, group_owner: nil, opened_at: DateTime.now)
          create(:notification, target: test_instance, group_owner: nil, opened_at: DateTime.now)
        end

        it "returns empty records" do
          expect(test_instance.unopened_notification_index).to be_empty
        end
      end
    end

    describe "#opened_notification_index" do
      context "when the target has no notifications" do
        it "returns empty records" do
          expect(test_instance.opened_notification_index).to be_empty
        end
      end

      context "when the target has opened notifications" do
        before do
          @notification_1 = create(:notification, target: test_instance, opened_at: DateTime.now)
          @notification_2 = create(:notification, target: test_instance, opened_at: DateTime.now)
        end

        context "without limit" do
          it "uses ActivityNotification.config.opened_index_limit as limit" do
            configured_opened_index_limit = ActivityNotification.config.opened_index_limit
            ActivityNotification.config.opened_index_limit = 1
            expect(test_instance.opened_notification_index.size).to eq(1)
            expect(test_instance.opened_notification_index.first).to eq(@notification_2)
            ActivityNotification.config.opened_index_limit = configured_opened_index_limit
          end

          it "returns opened notification index" do
            expect(test_instance.opened_notification_index.size).to eq(2)
            expect(test_instance.opened_notification_index.last).to  eq(@notification_1)
            expect(test_instance.opened_notification_index.first).to eq(@notification_2)
          end

          it "returns opened notification index (owner only)" do
            group_member   = create(:notification, target: test_instance, group_owner: @notification_1, opened_at: DateTime.now)
            expect(test_instance.opened_notification_index.size).to eq(2)
            expect(test_instance.opened_notification_index.last).to  eq(@notification_1)
            expect(test_instance.opened_notification_index.first).to eq(@notification_2)
          end

          it "returns opened notification index (opened only)" do
            notification_3 = create(:notification, target: test_instance)
            expect(test_instance.opened_notification_index.size).to eq(2)
            expect(test_instance.opened_notification_index.last).to  eq(@notification_1)
            expect(test_instance.opened_notification_index.first).to eq(@notification_2)
          end
        end

        context "with limit" do
          it "returns opened notification index with limit" do
            options = { limit: 1 }
            expect(test_instance.opened_notification_index(options).size).to eq(1)
            expect(test_instance.opened_notification_index(options).first).to eq(@notification_2)
          end
        end
      end

      context "when the target has no opened notifications" do
        before do
          create(:notification, target: test_instance, group_owner: nil)
          create(:notification, target: test_instance, group_owner: nil)
        end

        it "returns empty records" do
          expect(test_instance.opened_notification_index).to be_empty
        end
      end
    end


    # Wrapper methods of Notification class methods

    describe "#notify_to" do
      it "is an alias of ActivityNotification::Notification.notify_to" do
        expect(ActivityNotification::Notification).to receive(:notify_to)
        test_instance.notify_to create(:user)
      end
    end

    describe "#open_all_notifications" do
      it "is an alias of ActivityNotification::Notification.open_all_of" do
        expect(ActivityNotification::Notification).to receive(:open_all_of)
        test_instance.open_all_notifications
      end
    end


    # Methods to be overriden

    describe "#notification_index_with_attributes" do
      context "when the target has no notifications" do
        it "returns empty records" do
          expect(test_instance.notification_index_with_attributes).to be_empty
        end
      end

      context "when the target has unopened notifications" do
        before do
          @notifiable = create(:article)
          @group = create(:article)
          @key = 'test.key.1'
          create(:notification, target: test_instance, notifiable: @notifiable)
          create(:notification, target: test_instance, notifiable: create(:comment), group: @group)
          create(:notification, target: test_instance, notifiable: create(:article), key: @key).open!
        end

        it "calls unopened_notification_index_with_attributes" do
          expect(test_instance).to receive(:unopened_notification_index_with_attributes).at_least(:once)
          test_instance.notification_index_with_attributes
        end

        context "without limit" do
          it "returns the combined array of unopened_notification_index and opened_notification_index" do
            expect(test_instance.notification_index_with_attributes[0]).to eq(test_instance.unopened_notification_index[0])
            expect(test_instance.notification_index_with_attributes[1]).to eq(test_instance.unopened_notification_index[1])
            expect(test_instance.notification_index_with_attributes[2]).to eq(test_instance.opened_notification_index[0])
            expect(test_instance.notification_index_with_attributes.size).to eq(3)
          end
        end

        context "with limit" do
          it "returns the same as unopened_notification_index_with_attributes with limit" do
            options = { limit: 1 }
            expect(test_instance.notification_index_with_attributes(options)).to eq(test_instance.unopened_notification_index_with_attributes(options))
            expect(test_instance.notification_index_with_attributes(options).size).to eq(1)
          end
        end

        context "with reverse" do
          it "returns the earliest order" do
            options = { reverse: true }
            expect(test_instance.notification_index_with_attributes(options)[0]).to eq(test_instance.notification_index_with_attributes[1])
            expect(test_instance.notification_index_with_attributes(options)[1]).to eq(test_instance.notification_index_with_attributes[0])
            expect(test_instance.notification_index_with_attributes(options)[2]).to eq(test_instance.notification_index_with_attributes[2])
            expect(test_instance.notification_index_with_attributes(options).size).to eq(3)
          end
        end

        context 'with filtered_by_type options' do
          it "returns filtered notifications only" do
            options = { filtered_by_type: 'Article' }
            expect(test_instance.notification_index_with_attributes(options).size).to eq(2)
            options = { filtered_by_type: 'Comment' }
            expect(test_instance.notification_index_with_attributes(options).size).to eq(1)
          end
        end

        context 'with filtered_by_group options' do
          it "returns filtered notifications only" do
            options = { filtered_by_group: @group }
            expect(test_instance.notification_index_with_attributes(options).size).to eq(1)
          end
        end

        context 'with filtered_by_group_type and :filtered_by_group_id options' do
          it "returns filtered notifications only" do
            options = { filtered_by_group_type: 'Article', filtered_by_group_id: @group.id.to_s }
            expect(test_instance.notification_index_with_attributes(options).size).to eq(1)
          end
        end

        context 'with filtered_by_key options' do
          it "returns filtered notifications only" do
            options = { filtered_by_key: @key }
            expect(test_instance.notification_index_with_attributes(options).size).to eq(1)
          end
        end
      end

      context "when the target has no unopened notifications" do
        before do
          create(:notification, target: test_instance, opened_at: DateTime.now)
          create(:notification, target: test_instance, opened_at: DateTime.now)
        end

        it "calls unopened_notification_index_with_attributes" do
          expect(test_instance).to receive(:opened_notification_index_with_attributes)
          test_instance.notification_index_with_attributes
        end

        context "without limit" do
          it "returns the same as opened_notification_index_with_attributes" do
            expect(test_instance.notification_index_with_attributes).to eq(test_instance.opened_notification_index_with_attributes)
            expect(test_instance.notification_index_with_attributes.size).to eq(2)
          end
        end

        context "with limit" do
          it "returns the same as opened_notification_index_with_attributes with limit" do
            options = { limit: 1 }
            expect(test_instance.notification_index_with_attributes(options)).to eq(test_instance.opened_notification_index_with_attributes(options))
            expect(test_instance.notification_index_with_attributes(options).size).to eq(1)
          end
        end
      end
    end

    describe "#unopened_notification_index_with_attributes" do
      it "calls unopened_notification_index" do
        expect(test_instance).to receive(:unopened_notification_index)
        test_instance.unopened_notification_index_with_attributes
      end

      context "when the target has unopened notifications with no group members" do
        context "with no group members" do
          before do
            create(:notification, target: test_instance)
            create(:notification, target: test_instance)
          end
  
          it "calls with_target, with_notifiable and with_notifier" do
            expect(ActiveRecord::Base).to receive(:includes).with(:target)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifiable)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifier)
            test_instance.unopened_notification_index_with_attributes
          end
  
          it "does not call with_group" do
            expect(ActiveRecord::Base).to receive(:includes).with(:target)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifiable)
            expect(ActiveRecord::Base).not_to receive(:includes).with(:group)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifier)
            test_instance.unopened_notification_index_with_attributes
          end
        end
  
        context "with group members" do
          before do
            group_owner  = create(:notification, target: test_instance, group_owner: nil)
                           create(:notification, target: test_instance, group_owner: nil)
            group_member = create(:notification, target: test_instance, group_owner: group_owner)
          end
  
          it "calls with_group" do
            expect(ActiveRecord::Base).to receive(:includes).with(:target)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifiable)
            expect(ActiveRecord::Base).to receive(:includes).with(:group)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifier)
            test_instance.unopened_notification_index_with_attributes
          end
        end
      end

      context "when the target has no unopened notifications" do
        before do
          create(:notification, target: test_instance, opened_at: DateTime.now)
          create(:notification, target: test_instance, opened_at: DateTime.now)
        end

        it "returns empty records" do
          expect(test_instance.unopened_notification_index_with_attributes).to be_empty
        end
      end
    end

    describe "#opened_notification_index_with_attributes" do
      it "calls opened_notification_index" do
        expect(test_instance).to receive(:opened_notification_index)
        test_instance.opened_notification_index_with_attributes
      end

      context "when the target has opened notifications with no group members" do
        context "with no group members" do
          before do
            create(:notification, target: test_instance, opened_at: DateTime.now)
            create(:notification, target: test_instance, opened_at: DateTime.now)
          end
  
          it "calls with_target, with_notifiable and with_notifier" do
            expect(ActiveRecord::Base).to receive(:includes).with(:target)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifiable)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifier)
            test_instance.opened_notification_index_with_attributes
          end
  
          it "does not call with_group" do
            expect(ActiveRecord::Base).to receive(:includes).with(:target)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifiable)
            expect(ActiveRecord::Base).not_to receive(:includes).with(:group)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifier)
            test_instance.opened_notification_index_with_attributes
          end
        end
  
        context "with group members" do
          before do
            group_owner  = create(:notification, target: test_instance, group_owner: nil, opened_at: DateTime.now)
                           create(:notification, target: test_instance, group_owner: nil, opened_at: DateTime.now)
            group_member = create(:notification, target: test_instance, group_owner: group_owner, opened_at: DateTime.now)
          end
  
          it "calls with_group" do
            expect(ActiveRecord::Base).to receive(:includes).with(:target)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifiable)
            expect(ActiveRecord::Base).to receive(:includes).with(:group)
            expect(ActiveRecord::Base).to receive(:includes).with(:notifier)
            test_instance.opened_notification_index_with_attributes
          end
        end
      end

      context "when the target has no opened notifications" do
        before do
          create(:notification, target: test_instance)
          create(:notification, target: test_instance)
        end

        it "returns empty records" do
          expect(test_instance.opened_notification_index_with_attributes).to be_empty
        end
      end
    end

  end

end