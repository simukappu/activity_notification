shared_examples_for :notifiable do
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }
  let(:test_instance) { create(test_class_name) }
  let(:test_target) { create(:user) }

  include Rails.application.routes.url_helpers

  describe "as public class methods" do
    describe "#available_as_notifiable?" do
      it "returns true" do
        expect(described_class.available_as_notifiable?).to be_truthy
      end
    end

    describe "#set_notifiable_class_defaults" do
      it "set parameter fields as default" do
        described_class.set_notifiable_class_defaults
        expect(described_class._notification_targets).to       eq({})
        expect(described_class._notification_group).to         eq({})
        expect(described_class._notifier).to                   eq({})
        expect(described_class._notification_parameters).to    eq({})
        expect(described_class._notification_email_allowed).to eq({})
        expect(described_class._notifiable_path).to            eq({})
      end
    end    
  end

  describe "as public instance methods" do
    before do
      User.delete_all
      described_class.set_notifiable_class_defaults
      create(:user)
      create(:user)
      expect(User.all.count).to eq(2)
      expect(User.all.first).to be_an_instance_of(User)
    end

    describe "#notification_targets" do
      context "without any configuration" do
        it "raise NotImplementedError" do
          expect { test_instance.notification_targets(User, 'dummy_key') }
            .to raise_error(NotImplementedError, /You have to implement .+ or set :targets in acts_as_notifiable/)
        end
      end

      context "configured with overriden method" do
        it "returns specified value" do
          module AdditionalMethods
            def notification_users(key)
              User.all
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.notification_targets(User, 'dummy_key')).to eq(User.all)
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notification_targets[:users] = User.all
          expect(test_instance.notification_targets(User, 'dummy_key')).to eq(User.all)
        end

        it "returns specified symbol without argumentss" do
          module AdditionalMethods
            def custom_notification_users
              User.all
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_targets[:users] = :custom_notification_users
          expect(test_instance.notification_targets(User, 'dummy_key')).to eq(User.all)
        end

        it "returns specified symbol with key argument" do
          module AdditionalMethods
            def custom_notification_users(key)
              User.all
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_targets[:users] = :custom_notification_users
          expect(test_instance.notification_targets(User, 'dummy_key')).to eq(User.all)
        end

        it "returns specified lambda with single notifiable argument" do
          described_class._notification_targets[:users] = ->(notifiable){ User.all }
          expect(test_instance.notification_targets(User, 'dummy_key')).to eq(User.all)
        end

        it "returns specified lambda with notifiable and key arguments" do
          described_class._notification_targets[:users] = ->(notifiable, key){ User.all }
          expect(test_instance.notification_targets(User, 'dummy_key')).to eq(User.all)
        end
      end
    end

    describe "#notification_group" do
      context "without any configuration" do
        it "returns nil" do
          expect(test_instance.notification_group(User, 'dummy_key')).to be_nil
        end
      end

      context "configured with overriden method" do
        it "returns specified value" do
          module AdditionalMethods
            def notification_group_for_users(key)
              User.all.first
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.notification_group(User, 'dummy_key')).to eq(User.all.first)
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notification_group[:users] = User.all.first
          expect(test_instance.notification_group(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified symbol without argumentss" do
          module AdditionalMethods
            def custom_notification_group
              User.all.first
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_group[:users] = :custom_notification_group
          expect(test_instance.notification_group(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified symbol with key argument" do
          module AdditionalMethods
            def custom_notification_group(key)
              User.all.first
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_group[:users] = :custom_notification_group
          expect(test_instance.notification_group(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified lambda with single notifiable argument" do
          described_class._notification_group[:users] = ->(notifiable){ User.all.first }
          expect(test_instance.notification_group(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified lambda with notifiable and key arguments" do
          described_class._notification_group[:users] = ->(notifiable, key){ User.all.first }
          expect(test_instance.notification_group(User, 'dummy_key')).to eq(User.all.first)
        end
      end
    end

    describe "#notification_parameters" do
      context "without any configuration" do
        it "returns blank hash" do
          expect(test_instance.notification_parameters(User, 'dummy_key')).to eq({})
        end
      end

      context "configured with overriden method" do
        it "returns specified value" do
          module AdditionalMethods
            def notification_parameters_for_users(key)
              { hoge: 'fuga', foo: 'bar' }
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.notification_parameters(User, 'dummy_key')).to eq({ hoge: 'fuga', foo: 'bar' })
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notification_parameters[:users] = { hoge: 'fuga', foo: 'bar' }
          expect(test_instance.notification_parameters(User, 'dummy_key')).to eq({ hoge: 'fuga', foo: 'bar' })
        end

        it "returns specified symbol without arguments" do
          module AdditionalMethods
            def custom_notification_parameters
              { hoge: 'fuga', foo: 'bar' }
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_parameters[:users] = :custom_notification_parameters
          expect(test_instance.notification_parameters(User, 'dummy_key')).to eq({ hoge: 'fuga', foo: 'bar' })
        end

        it "returns specified symbol with key argument" do
          module AdditionalMethods
            def custom_notification_parameters(key)
              { hoge: 'fuga', foo: 'bar' }
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_parameters[:users] = :custom_notification_parameters
          expect(test_instance.notification_parameters(User, 'dummy_key')).to eq({ hoge: 'fuga', foo: 'bar' })
        end

        it "returns specified lambda with single notifiable argument" do
          described_class._notification_parameters[:users] = ->(notifiable){ { hoge: 'fuga', foo: 'bar' } }
          expect(test_instance.notification_parameters(User, 'dummy_key')).to eq({ hoge: 'fuga', foo: 'bar' })
        end

        it "returns specified lambda with notifiable and key arguments" do
          described_class._notification_parameters[:users] = ->(notifiable, key){ { hoge: 'fuga', foo: 'bar' } }
          expect(test_instance.notification_parameters(User, 'dummy_key')).to eq({ hoge: 'fuga', foo: 'bar' })
        end
      end
    end

    describe "#notifier" do
      context "without any configuration" do
        it "returns nil" do
          expect(test_instance.notifier(User, 'dummy_key')).to be_nil
        end
      end

      context "configured with overriden method" do
        it "returns specified value" do
          module AdditionalMethods
            def notifier_for_users(key)
              User.all.first
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.notifier(User, 'dummy_key')).to eq(User.all.first)
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notifier[:users] = User.all.first
          expect(test_instance.notifier(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified symbol without arguments" do
          module AdditionalMethods
            def custom_notifier
              User.all.first
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notifier[:users] = :custom_notifier
          expect(test_instance.notifier(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified symbol with key argument" do
          module AdditionalMethods
            def custom_notifier(key)
              User.all.first
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notifier[:users] = :custom_notifier
          expect(test_instance.notifier(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified lambda with single notifiable argument" do
          described_class._notifier[:users] = ->(notifiable){ User.all.first }
          expect(test_instance.notifier(User, 'dummy_key')).to eq(User.all.first)
        end

        it "returns specified lambda with notifiable and key arguments" do
          described_class._notifier[:users] = ->(notifiable, key){ User.all.first }
          expect(test_instance.notifier(User, 'dummy_key')).to eq(User.all.first)
        end
      end
    end

    describe "#notification_email_allowed?" do
      context "without any configuration" do
        it "returns ActivityNotification.config.email_enabled" do
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key'))
            .to eq(ActivityNotification.config.email_enabled)
        end

        it "returns false as default" do
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key')).to be_falsey
        end
      end

      context "configured with overriden method" do
        it "returns specified value" do
          module AdditionalMethods
            def notification_email_allowed_for_users?(target, key)
              true
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key')).to eq(true)
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notification_email_allowed[:users] = true
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key')).to eq(true)
        end

        it "returns specified symbol without arguments" do
          module AdditionalMethods
            def custom_notification_email_allowed?
              true
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_email_allowed[:users] = :custom_notification_email_allowed?
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key')).to eq(true)
        end

        it "returns specified symbol with target and key arguments" do
          module AdditionalMethods
            def custom_notification_email_allowed?(target, key)
              true
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notification_email_allowed[:users] = :custom_notification_email_allowed?
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key')).to eq(true)
        end

        it "returns specified lambda with single notifiable argument" do
          described_class._notification_email_allowed[:users] = ->(notifiable){ true }
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key')).to eq(true)
        end

        it "returns specified lambda with notifiable, target and key arguments" do
          described_class._notification_email_allowed[:users] = ->(notifiable, target, key){ true }
          expect(test_instance.notification_email_allowed?(test_target, 'dummy_key')).to eq(true)
        end
      end
    end

    describe "#notifiable_path" do
      context "without any configuration" do
        it "raise NotImplementedError" do
          expect { test_instance.notifiable_path(User, 'dummy_key') }
            .to raise_error(NotImplementedError, /You have to implement .+, set :notifiable_path in acts_as_notifiable or set polymorphic_path routing for/)
        end
      end

      context "configured with polymorphic_path" do
        it "returns polymorphic_path" do
          article = create(:article)
          expect(article.notifiable_path(User, 'dummy_key')).to eq(article_path(article))
        end
      end

      context "configured with overriden method" do
        it "returns specified value" do
          module AdditionalMethods
            def notifiable_path_for_users(key)
              article_path(1)
            end
          end
          test_instance.extend(AdditionalMethods)
          expect(test_instance.notifiable_path(User, 'dummy_key')).to eq(article_path(1))
        end
      end

      context "configured with a field" do
        it "returns specified value" do
          described_class._notifiable_path[:users] = article_path(1)
          expect(test_instance.notifiable_path(User, 'dummy_key')).to eq(article_path(1))
        end

        it "returns specified symbol without arguments" do
          module AdditionalMethods
            def custom_notifiable_path
              article_path(1)
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notifiable_path[:users] = :custom_notifiable_path
          expect(test_instance.notifiable_path(User, 'dummy_key')).to eq(article_path(1))
        end

        it "returns specified symbol with key argument" do
          module AdditionalMethods
            def custom_notifiable_path(key)
              article_path(1)
            end
          end
          test_instance.extend(AdditionalMethods)
          described_class._notifiable_path[:users] = :custom_notifiable_path
          expect(test_instance.notifiable_path(User, 'dummy_key')).to eq(article_path(1))
        end

        it "returns specified lambda with single notifiable argument" do
          described_class._notifiable_path[:users] = ->(notifiable){ article_path(1) }
          expect(test_instance.notifiable_path(User, 'dummy_key')).to eq(article_path(1))
        end

        it "returns specified lambda with notifiable and key arguments" do
          described_class._notifiable_path[:users] = ->(notifiable, key){ article_path(1) }
          expect(test_instance.notifiable_path(User, 'dummy_key')).to eq(article_path(1))
        end
      end
    end

    describe "#notify" do
      it "is an alias of ActivityNotification::Notification.notify" do
        expect(ActivityNotification::Notification).to receive(:notify)
        test_instance.notify :users
      end
    end

    describe "#notify_to" do
      it "is an alias of ActivityNotification::Notification.notify_to" do
        expect(ActivityNotification::Notification).to receive(:notify_to)
        test_instance.notify_to create(:user)
      end
    end

    describe "#notify_all" do
      it "is an alias of ActivityNotification::Notification.notify_all" do
        expect(ActivityNotification::Notification).to receive(:notify_all)
        test_instance.notify_all [create(:user)]
      end
    end

    describe "#default_notification_key" do
      it "returns '#to_resource_name.default'" do
        expect(test_instance.default_notification_key).to eq("#{test_instance.to_resource_name}.default")
      end
    end

  end

end