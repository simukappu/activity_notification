require 'generators/activity_notification/views_generator'

describe ActivityNotification::Generators::ViewsGenerator, type: :generator do

  # setup_default_destination
  destination File.expand_path("../../../tmp", __FILE__)
  before { prepare_destination }

  it 'runs generating views tasks' do
    gen = generator
    expect(gen).to receive :copy_views
    gen.invoke_all
  end

  describe 'the generated files' do
    context 'without target argument' do
      context 'with target views as default' do
        before do
          run_generator
        end

        describe 'the notification views' do
          describe 'default/_default.html.erb' do
            subject { file('app/views/activity_notification/notifications/default/_default.html.erb') }
            it { is_expected.to exist }
          end

          describe 'default/_index.html.erb' do
            subject { file('app/views/activity_notification/notifications/default/_index.html.erb') }
            it { is_expected.to exist }
          end

          describe 'default/destroy.js.erb' do
            subject { file('app/views/activity_notification/notifications/default/destroy.js.erb') }
            it { is_expected.to exist }
          end

          describe 'default/index.html.erb' do
            subject { file('app/views/activity_notification/notifications/default/index.html.erb') }
            it { is_expected.to exist }
          end

          describe 'default/open_all.js.erb' do
            subject { file('app/views/activity_notification/notifications/default/open_all.js.erb') }
            it { is_expected.to exist }
          end

          describe 'default/open.js.erb' do
            subject { file('app/views/activity_notification/notifications/default/open.js.erb') }
            it { is_expected.to exist }
          end

          describe 'default/show.html.erb' do
            subject { file('app/views/activity_notification/notifications/default/show.html.erb') }
            it { is_expected.to exist }
          end
        end

        describe 'the mailer views' do
          describe 'default/default.html.erb' do
            subject { file('app/views/activity_notification/mailer/default/default.html.erb') }
            it { is_expected.to exist }
          end
        end
      end

      context 'with a views option as notifications' do
        before do
          run_generator %w(--views notifications)
        end

        describe 'the notification views' do
          describe 'default/index.html.erb' do
            subject { file('app/views/activity_notification/notifications/default/index.html.erb') }
            it { is_expected.to exist }
          end
        end

        describe 'the mailer views' do
          describe 'default/default.html.erb' do
            subject { file('app/views/activity_notification/mailer/default/default.html.erb') }
            it { is_expected.not_to exist }
          end
        end
      end
    end

    context 'with users as target' do
      context 'with target views as default' do
        before do
          run_generator %w(users)
        end

        describe 'the notification views' do
          describe 'users/index.html.erb' do
            subject { file('app/views/activity_notification/notifications/users/index.html.erb') }
            it { is_expected.to exist }
          end
        end

        describe 'the mailer views' do
          describe 'users/default.html.erb' do
            subject { file('app/views/activity_notification/mailer/users/default.html.erb') }
            it { is_expected.to exist }
          end
        end
      end
    end

  end
end