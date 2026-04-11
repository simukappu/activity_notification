require 'generators/activity_notification/add_notifiable_to_subscriptions/add_notifiable_to_subscriptions_generator'

describe ActivityNotification::Generators::AddNotifiableToSubscriptionsGenerator, type: :generator do

  destination File.expand_path("../../../../tmp", __FILE__)

  before do
    prepare_destination
  end

  after do
    if ActivityNotification.config.orm == :active_record
      ActivityNotification::Subscription.reset_column_information
    end
  end

  it 'runs generating migration task' do
    gen = generator
    expect(gen).to receive :create_migration_file
    gen.invoke_all
  end

  describe 'the generated files' do
    context 'without name argument' do
      before do
        run_generator
      end

      describe 'AddNotifiableToSubscriptions migration file' do
        subject { file(Dir["tmp/db/migrate/*_add_notifiable_to_subscriptions.rb"].first.gsub!('tmp/', '')) }
        it { is_expected.to exist }
        it { is_expected.to contain(/class AddNotifiableToSubscriptions < ActiveRecord::Migration\[\d\.\d\]/) }
        it { is_expected.to contain(/add_reference :subscriptions, :notifiable/) }
        it { is_expected.to contain(/remove_index :subscriptions/) }
        it { is_expected.to contain(/index_subscriptions_uniqueness/) }
      end
    end
  end
end
