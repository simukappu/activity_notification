require 'generators/activity_notification/notification/notification_generator'

describe ActivityNotification::Generators::NotificationGenerator, type: :generator do

  # setup_default_destination
  destination File.expand_path("../../../../tmp", __FILE__)
  before { prepare_destination }

  it 'runs generating model tasks' do
    gen = generator
    expect(gen).to receive :create_models
    gen.invoke_all
  end

  describe 'the generated files' do
    context 'without name argument' do
      before do
        run_generator
      end

      describe 'app/models/notification.rb' do
        subject { file('app/models/notification.rb') }
        it { is_expected.to exist }
        it { is_expected.to contain(/class Notification < ActivityNotification::Notification/) }
      end
    end

    context 'with CustomNotification as name argument' do
      before do
        run_generator %w(CustomNotification)
      end

      describe 'app/models/notification.rb' do
        subject { file('app/models/custom_notification.rb') }
        it { is_expected.to exist }
        it { is_expected.to contain(/class CustomNotification < ActivityNotification::Notification/) }
      end
    end

  end
end