describe ActivityNotification::ViewHelpers, type: :helper do
  let(:view_context) { ActionView::Base.new }
  let(:notification) do
    create(:notification, target: create(:confirmed_user))
  end
  let(:notification_2) do
    create(:notification, target: create(:confirmed_user))
  end
  let(:notifications) do
    target = create(:confirmed_user)
    create(:notification, target: target)
    create(:notification, target: target)
    target.notifications.group_owners_only
  end
  let(:target_user) do
    target = create(:confirmed_user)
    create(:notification, target: target)
    create(:notification, target: target)
    target
  end

  include ActivityNotification::ViewHelpers

  describe 'ActionView::Base' do
    it 'provides render_notification helper' do
      expect(view_context.respond_to?(:render_notification)).to be_truthy
    end
  end

  describe '#render_notification' do
    context "without fallback" do
      context "when the template is missing for the target type and key" do
        it "raise ActionView::MissingTemplate" do
          expect { render_notification notification }
            .to raise_error(ActionView::MissingTemplate)
        end
      end
    end

    context "with default as fallback" do
      it "renders default notification view" do
        expect(render_notification notification, fallback: :default)
          .to eq(
            render partial: 'activity_notification/notifications/default/default',
                   locals: { notification: notification }
          )
      end
  
      it 'handles multiple notifications of active_record' do
        expect(notifications.to_a.first).to receive(:render).with(self, { fallback: :default })
        expect(notifications.to_a.last).to  receive(:render).with(self, { fallback: :default })
        render_notification notifications, fallback: :default
      end
  
      it 'handles multiple notifications of array' do
        expect(notification).to receive(:render).with(self, { fallback: :default })
        expect(notification_2).to receive(:render).with(self, { fallback: :default })
        render_notification [notification, notification_2], fallback: :default
      end
    end

    context "with custom view" do
      it "renders custom notification view for default target" do
        notification.key = 'custom.test'
        # render activity_notification/notifications/default/custom/test
        expect(render_notification notification, fallback: :default)
          .to eq("Custom template root for default target: #{notification.id}")
      end
  
      it "renders custom notification view for specified target" do
        notification.key = 'custom.test'
        # render activity_notification/notifications/users/custom/test
        expect(render_notification notification, target: :users, fallback: :default)
          .to eq("Custom template root for user target: #{notification.id}")
      end
    end
  end

  describe '#render_notifications' do
    it "is an alias of render_notification" do
      # expect(self).to receive(:render_notification).with(notifications, { fallback: :default })
      # render_notifications notifications, fallback: :default
    end
  end

  describe '#render_notification_of' do
    context "without fallback" do
      context "when the template is missing for the target type and key" do
        it "raise ActionView::MissingTemplate" do
          expect { render_notification_of target_user }
            .to raise_error(ActionView::MissingTemplate)
        end
      end
    end

    context "with default as fallback" do
      # it "renders default notification view" do
        # expect(render_notification_of target_user, fallback: :default)
          # .to eq(
            # render partial: 'activity_notification/notifications/default/index',
                   # locals: { target: target_user }
          # )
      # end
    end

    context "with custom view" do
      # it "renders custom notification view for specified target" do
        # notification_1 = target_user.notifications.first
        # notification_2 = target_user.notifications.last
        # notification_1.update(key: 'custom.test')
        # notification_2.update(key: 'custom.test')
        # expect(render_notification_of target_user, fallback: :default)
          # .to eq("Custom index: Custom template root for user target: #{notification_1.id}"\
                               # "Custom template root for user target: #{notification_2.id}")
      # end
    end
  end

  describe '#render_notifications_of' do
    it "is an alias of render_notification_of" do
      # expect(self).to receive(:render_notification_of).with(notifications, { fallback: :default })
      # render_notifications_of notifications, fallback: :default
    end
  end

end
