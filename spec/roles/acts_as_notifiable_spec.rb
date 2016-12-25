describe ActivityNotification::ActsAsNotifiable do
  let(:dummy_model_class)      { Dummy::DummyBase }
  let(:dummy_notifiable_class) { Dummy::DummyNotifiable }
  let(:dummy_target)           { create(:dummy_target) }

  describe "as public class methods" do
    describe ".acts_as_notifiable" do
      it "have not included Notifiable before calling" do
        expect(dummy_model_class.respond_to?(:available_as_notifiable?)).to be_falsey
      end

      it "includes Notifiable" do
        dummy_model_class.acts_as_notifiable :users
        expect(dummy_model_class.respond_to?(:available_as_notifiable?)).to be_truthy
        expect(dummy_model_class.available_as_notifiable?).to be_truthy
      end

      context "with no options" do
        it "returns hash of specified options" do
          expect(dummy_model_class.acts_as_notifiable :users).to eq({})
        end
      end

      context "with :dependent_notifications option" do
        before do
          dummy_notifiable_class.reset_callbacks :destroy
          @notifiable_1, @notifiable_2, @notifiable_3 = dummy_notifiable_class.create, dummy_notifiable_class.create, dummy_notifiable_class.create
          @group_owner  = create(:notification, target: dummy_target, notifiable: @notifiable_1, group: @notifiable_1)
          @group_member = create(:notification, target: dummy_target, notifiable: @notifiable_2, group: @notifiable_1, group_owner: @group_owner)
                          create(:notification, target: dummy_target, notifiable: @notifiable_3, group: @notifiable_1, group_owner: @group_owner)
          expect(@group_owner.group_member_count).to eq(2)
        end

        it "returns hash of :dependent_notifications option" do
          expect(dummy_notifiable_class.acts_as_notifiable :users, dependent_notifications: :restrict_with_exception)
            .to eq({ dependent_notifications: :restrict_with_exception })
        end

        context "without option" do
          it "does not deletes any notifications when notifiable is deleted" do
            dummy_notifiable_class.acts_as_notifiable :users
            expect(dummy_target.notifications.reload.size).to eq(3)
            expect { @notifiable_1.destroy }.to change(dummy_notifiable_class, :count).by(-1)
            expect(dummy_target.notifications.reload.size).to eq(3)
          end
        end

        context ":delete_all" do
          it "deletes all notifications when notifiable is deleted" do
            dummy_notifiable_class.acts_as_notifiable :users, dependent_notifications: :delete_all
            expect(dummy_target.notifications.reload.size).to eq(3)
            expect { @notifiable_1.destroy }.to change(dummy_notifiable_class, :count).by(-1)
            expect(dummy_target.notifications.reload.size).to eq(2)
            expect(@group_member.reload.group_owner?).to be_falsey
          end
        end

        context ":destroy" do
          it "destroies all notifications when notifiable is deleted" do
            dummy_notifiable_class.acts_as_notifiable :users, dependent_notifications: :destroy
            expect(dummy_target.notifications.reload.size).to eq(3)
            expect { @notifiable_1.destroy }.to change(dummy_notifiable_class, :count).by(-1)
            expect(dummy_target.notifications.reload.size).to eq(2)
            expect(@group_member.reload.group_owner?).to be_falsey
          end
        end

        context ":restrict_with_exception" do
          it "can not be deleted when it has generated notifications" do
            dummy_notifiable_class.acts_as_notifiable :users, dependent_notifications: :restrict_with_exception
            expect(dummy_target.notifications.reload.size).to eq(3)
            expect { @notifiable_1.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
          end
        end

        context ":update_group_and_delete_all" do
          it "deletes all notifications and update notification group when notifiable is deleted" do
            dummy_notifiable_class.acts_as_notifiable :users, dependent_notifications: :update_group_and_delete_all
            expect(dummy_target.notifications.reload.size).to eq(3)
            expect { @notifiable_1.destroy }.to change(dummy_notifiable_class, :count).by(-1)
            expect(dummy_target.notifications.reload.size).to eq(2)
            expect(@group_member.reload.group_owner?).to be_truthy
          end
        end

        context ":update_group_and_destroy" do
          it "destroies all notifications and update notification group when notifiable is deleted" do
            dummy_notifiable_class.acts_as_notifiable :users, dependent_notifications: :update_group_and_destroy
            expect(dummy_target.notifications.reload.size).to eq(3)
            expect { @notifiable_1.destroy }.to change(dummy_notifiable_class, :count).by(-1)
            expect(dummy_target.notifications.reload.size).to eq(2)
            expect(@group_member.reload.group_owner?).to be_truthy
          end
        end
      end

      #TODO test other options
    end

    describe ".available_notifiable_options" do
      it "returns list of available options in acts_as_notifiable" do
        expect(dummy_model_class.available_notifiable_options)
          .to eq([:targets, :group, :group_expiry_delay, :notifier, :parameters, :email_allowed, :notifiable_path, :printable_notifiable_name, :printable_name, :dependent_notifications])
      end
    end
  end
end