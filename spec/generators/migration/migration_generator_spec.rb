require 'generators/activity_notification/migration/migration_generator'

describe ActivityNotification::Generators::MigrationGenerator, type: :generator do

  # setup_default_destination
  destination File.expand_path("../../../../tmp", __FILE__)
  before { prepare_destination }

  it 'runs generating migration tasks' do
    gen = generator
    expect(gen).to receive :create_migrations
    gen.invoke_all
  end

  describe 'the generated files' do
    context 'without name argument' do
      before do
        run_generator
      end

      describe 'CreateNotifications migration file' do
        subject { file(Dir["tmp/db/migrate/*_create_activity_notification_tables.rb"].first.gsub!('tmp/', '')) }
        it { is_expected.to exist }
        it { is_expected.to contain(/class CreateActivityNotificationTables < ActiveRecord::Migration/) }
      end
    end

    context 'with CreateCustomNotifications as name argument' do
      before do
        run_generator %w(CreateCustomNotifications --tables notifications)
      end

      describe 'CreateCustomNotifications migration file' do
        subject { file(Dir["tmp/db/migrate/*_create_custom_notifications.rb"].first.gsub!('tmp/', '')) }
        it { is_expected.to exist }
        it { is_expected.to contain(/class CreateCustomNotifications < ActiveRecord::Migration/) }
      end
    end

  end
end