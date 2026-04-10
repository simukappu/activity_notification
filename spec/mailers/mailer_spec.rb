describe ActivityNotification::Mailer do
  include ActiveJob::TestHelper
  let(:notification) { create(:notification) }
  let(:test_target) { notification.target }
  let(:notifications) { [create(:notification, target: test_target), create(:notification, target: test_target)] }
  let(:batch_key) { 'test_batch_key' }

  before do
    ActivityNotification::Mailer.deliveries.clear
    expect(ActivityNotification::Mailer.deliveries.size).to eq(0)
  end

  describe ".send_notification_email" do
    context "with deliver_now" do
      context "as default" do
        before do
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
        end
  
        it "sends notification email now" do
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
        end
  
        it "sends to target email" do
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(notification.target.email)
        end
  
        it "sends from configured email in initializer" do
          expect(ActivityNotification::Mailer.deliveries.last.from[0])
            .to eq("please-change-me-at-config-initializers-activity_notification@example.com")
        end

        it "sends with default notification subject" do
          expect(ActivityNotification::Mailer.deliveries.last.subject)
            .to eq("Notification of article")
        end
      end

      context "with default from parameter in mailer" do
        it "sends from configured email as default parameter" do
          class CustomMailer < ActivityNotification::Mailer
            default from: "test01@example.com"
          end
          CustomMailer.send_notification_email(notification).deliver_now
          expect(CustomMailer.deliveries.last.from[0])
            .to eq("test01@example.com")
        end
      end

      context "with email value as ActivityNotification.config.mailer_sender" do
        it "sends from configured email as ActivityNotification.config.mailer_sender" do
          ActivityNotification.config.mailer_sender = "test02@example.com"
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.from[0])
            .to eq("test02@example.com")
        end
      end

      context "with email proc as ActivityNotification.config.mailer_sender" do
        it "sends from configured email as ActivityNotification.config.mailer_sender" do
          ActivityNotification.config.mailer_sender =
            ->(key){ key == notification.key ? "test03@example.com" : "test04@example.com" }
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.from[0])
            .to eq("test03@example.com")
        end

        it "sends from configured email as ActivityNotification.config.mailer_sender" do
          ActivityNotification.config.mailer_sender =
            ->(key){ key == 'hogehoge' ? "test03@example.com" : "test04@example.com" }
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.from[0])
            .to eq("test04@example.com")
        end
      end

      context "with defined overriding_notification_email_key in notifiable model" do
        it "sends with configured notification subject in locale file as updated key" do
          module AdditionalMethods
            def overriding_notification_email_key(target, key)
              'comment.reply'
            end
          end
          notification.notifiable.extend(AdditionalMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.subject)
            .to eq("New comment on your article")
        end
      end

      context "with defined overriding_notification_email_subject in notifiable model" do
        it "sends with updated subject" do
          module AdditionalMethods
            def overriding_notification_email_subject(target, key)
              'Hi, You have got comment'
            end
          end
          notification.notifiable.extend(AdditionalMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.subject)
            .to eq("Hi, You have got comment")
        end
      end

      context "with defined overriding_notification_email_from in notifiable model" do
        it "sends with updated from" do
          module AdditionalMethods
            def overriding_notification_email_from(target, key)
              'test05@example.com'
            end
          end
          notification.notifiable.extend(AdditionalMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.from.first)
            .to eq('test05@example.com')
        end
      end

      context "with defined overriding_notification_email_reply_to in notifiable model" do
        it "sends with updated reply_to" do
          module AdditionalMethods
            def overriding_notification_email_reply_to(target, key)
              'test06@example.com'
            end
          end
          notification.notifiable.extend(AdditionalMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.reply_to.first)
            .to eq('test06@example.com')
        end
      end

      context "with defined mailer_cc in target model" do
        context "as single email address" do
          it "sends with cc" do
            module TargetCCMethods
              def mailer_cc
                'cc@example.com'
              end
            end
            notification.target.extend(TargetCCMethods)
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            expect(ActivityNotification::Mailer.deliveries.last.cc).not_to be_nil
            expect(ActivityNotification::Mailer.deliveries.last.cc.first)
              .to eq('cc@example.com')
          end
        end

        context "as array of email addresses" do
          it "sends with multiple cc recipients" do
            module TargetCCArrayMethods
              def mailer_cc
                ['cc1@example.com', 'cc2@example.com']
              end
            end
            notification.target.extend(TargetCCArrayMethods)
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            expect(ActivityNotification::Mailer.deliveries.last.cc).not_to be_nil
            expect(ActivityNotification::Mailer.deliveries.last.cc)
              .to match_array(['cc1@example.com', 'cc2@example.com'])
          end
        end

        context "as nil" do
          it "does not send with cc" do
            module TargetCCNilMethods
              def mailer_cc
                nil
              end
            end
            notification.target.extend(TargetCCNilMethods)
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            expect(ActivityNotification::Mailer.deliveries.last.cc).to be_nil
          end
        end
      end

      context "without mailer_cc in target model" do
        it "does not send with cc" do
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc).to be_nil
        end

        context "with email value as ActivityNotification.config.mailer_cc" do
          it "sends with configured cc from global config" do
            original_config = ActivityNotification.config.mailer_cc
            ActivityNotification.config.mailer_cc = "config_cc@example.com"
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            expect(ActivityNotification::Mailer.deliveries.last.cc).not_to be_nil
            expect(ActivityNotification::Mailer.deliveries.last.cc.first)
              .to eq("config_cc@example.com")
            ActivityNotification.config.mailer_cc = original_config
          end
        end

        context "with email array as ActivityNotification.config.mailer_cc" do
          it "sends with multiple configured cc from global config" do
            original_config = ActivityNotification.config.mailer_cc
            ActivityNotification.config.mailer_cc = ["config_cc1@example.com", "config_cc2@example.com"]
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            expect(ActivityNotification::Mailer.deliveries.last.cc).not_to be_nil
            expect(ActivityNotification::Mailer.deliveries.last.cc)
              .to match_array(["config_cc1@example.com", "config_cc2@example.com"])
            ActivityNotification.config.mailer_cc = original_config
          end
        end

        context "with email proc as ActivityNotification.config.mailer_cc" do
          it "sends with configured cc from global config proc" do
            original_config = ActivityNotification.config.mailer_cc
            ActivityNotification.config.mailer_cc =
              ->(key){ key == notification.key ? "proc_cc@example.com" : "other_cc@example.com" }
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            expect(ActivityNotification::Mailer.deliveries.last.cc).not_to be_nil
            expect(ActivityNotification::Mailer.deliveries.last.cc.first)
              .to eq("proc_cc@example.com")
            ActivityNotification.config.mailer_cc = original_config
          end

          it "sends with configured cc from global config proc with different key" do
            original_config = ActivityNotification.config.mailer_cc
            ActivityNotification.config.mailer_cc =
              ->(key){ key == 'different.key' ? "proc_cc@example.com" : "other_cc@example.com" }
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            expect(ActivityNotification::Mailer.deliveries.last.cc).not_to be_nil
            expect(ActivityNotification::Mailer.deliveries.last.cc.first)
              .to eq("other_cc@example.com")
            ActivityNotification.config.mailer_cc = original_config
          end
        end
      end

      context "with defined overriding_notification_email_cc in notifiable model" do
        it "sends with updated cc" do
          module AdditionalMethods
            def overriding_notification_email_cc(target, key)
              'override_cc@example.com'
            end
          end
          notification.notifiable.extend(AdditionalMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc.first)
            .to eq('override_cc@example.com')
        end

        it "sends with updated cc as array" do
          module AdditionalMethodsArray
            def overriding_notification_email_cc(target, key)
              ['override_cc1@example.com', 'override_cc2@example.com']
            end
          end
          notification.notifiable.extend(AdditionalMethodsArray)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc)
            .to match_array(['override_cc1@example.com', 'override_cc2@example.com'])
        end

        it "overrides target mailer_cc method" do
          module TargetCCMethodsBase
            def mailer_cc
              'target_cc@example.com'
            end
          end
          module NotifiableOverrideMethods
            def overriding_notification_email_cc(target, key)
              'notifiable_override_cc@example.com'
            end
          end
          notification.target.extend(TargetCCMethodsBase)
          notification.notifiable.extend(NotifiableOverrideMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc.first)
            .to eq('notifiable_override_cc@example.com')
        end

        it "overrides global config and target mailer_cc method" do
          original_config = ActivityNotification.config.mailer_cc
          ActivityNotification.config.mailer_cc = "config_cc@example.com"
          
          module TargetCCMethodsWithConfig
            def mailer_cc
              'target_cc@example.com'
            end
          end
          module NotifiableOverrideMethodsWithConfig
            def overriding_notification_email_cc(target, key)
              'notifiable_override_cc@example.com'
            end
          end
          notification.target.extend(TargetCCMethodsWithConfig)
          notification.notifiable.extend(NotifiableOverrideMethodsWithConfig)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc.first)
            .to eq('notifiable_override_cc@example.com')
          
          ActivityNotification.config.mailer_cc = original_config
        end
      end

      context "with mailer_cc priority resolution" do
        it "uses target mailer_cc over global config" do
          original_config = ActivityNotification.config.mailer_cc
          ActivityNotification.config.mailer_cc = "config_cc@example.com"
          
          module TargetCCOverConfig
            def mailer_cc
              'target_cc@example.com'
            end
          end
          notification.target.extend(TargetCCOverConfig)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc.first)
            .to eq('target_cc@example.com')
          
          ActivityNotification.config.mailer_cc = original_config
        end
      end

      context "with defined overriding_notification_email_message_id in notifiable model" do
        it "sends with specific message id" do
          module AdditionalMethods
            def overriding_notification_email_message_id(target, key)
              "https://www.example.com/test@example.com/"
            end
          end
          notification.notifiable.extend(AdditionalMethods)
          ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.message_id)
            .to eq("https://www.example.com/test@example.com/")
        end
      end
      context "with mailer_attachments" do
        after do
          ActivityNotification.config.mailer_attachments = nil
        end

        context "with global config as Hash" do
          it "includes attachment in email" do
            ActivityNotification.config.mailer_attachments = { filename: 'test.txt', content: 'hello' }
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(1)
            expect(mail.attachments.first.filename).to eq('test.txt')
          end
        end

        context "with global config as Array" do
          it "includes multiple attachments in email" do
            ActivityNotification.config.mailer_attachments = [
              { filename: 'a.txt', content: 'aaa' },
              { filename: 'b.txt', content: 'bbb' }
            ]
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(2)
            expect(mail.attachments.map(&:filename)).to match_array(['a.txt', 'b.txt'])
          end
        end

        context "with global config as Proc" do
          it "calls proc with notification key" do
            ActivityNotification.config.mailer_attachments = ->(key) {
              key == notification.key ? { filename: 'dynamic.txt', content: 'from proc' } : nil
            }
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(1)
            expect(mail.attachments.first.filename).to eq('dynamic.txt')
          end

          it "sends without attachments when proc returns nil" do
            ActivityNotification.config.mailer_attachments = ->(key) { nil }
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(0)
          end
        end

        context "with path-based attachment" do
          it "reads file content from path" do
            tmpfile = Tempfile.new(['test', '.txt'])
            tmpfile.write('file content')
            tmpfile.close
            ActivityNotification.config.mailer_attachments = { filename: 'from_path.txt', path: tmpfile.path }
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(1)
            expect(mail.attachments.first.filename).to eq('from_path.txt')
            tmpfile.unlink
          end
        end

        context "with mime_type specified" do
          it "uses the specified mime_type" do
            ActivityNotification.config.mailer_attachments = { filename: 'data.bin', content: 'binary', mime_type: 'application/octet-stream' }
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(1)
            expect(mail.attachments.first.content_type).to include('application/octet-stream')
          end
        end

        context "with target mailer_attachments method" do
          it "uses target attachments over global config" do
            ActivityNotification.config.mailer_attachments = { filename: 'global.txt', content: 'global' }
            module TargetAttachmentMethods
              def mailer_attachments
                { filename: 'target.txt', content: 'target' }
              end
            end
            notification.target.extend(TargetAttachmentMethods)
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(1)
            expect(mail.attachments.first.filename).to eq('target.txt')
          end
        end

        context "with notifiable overriding_notification_email_attachments" do
          it "uses notifiable override over target and global" do
            ActivityNotification.config.mailer_attachments = { filename: 'global.txt', content: 'global' }
            module TargetAttachmentMethodsBase
              def mailer_attachments
                { filename: 'target.txt', content: 'target' }
              end
            end
            module NotifiableAttachmentOverride
              def overriding_notification_email_attachments(target, key)
                { filename: 'override.txt', content: 'override' }
              end
            end
            notification.target.extend(TargetAttachmentMethodsBase)
            notification.notifiable.extend(NotifiableAttachmentOverride)
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(1)
            expect(mail.attachments.first.filename).to eq('override.txt')
          end
        end

        context "without any attachment configuration" do
          it "sends email without attachments" do
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
            mail = ActivityNotification::Mailer.deliveries.last
            expect(mail.attachments.size).to eq(0)
          end
        end
      end

      context "with invalid attachment specification" do
        after do
          ActivityNotification.config.mailer_attachments = nil
        end

        it "raises ArgumentError for missing filename" do
          ActivityNotification.config.mailer_attachments = { content: 'data' }
          expect {
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          }.to raise_error(ArgumentError, /filename/)
        end

        it "raises ArgumentError for missing content and path" do
          ActivityNotification.config.mailer_attachments = { filename: 'test.txt' }
          expect {
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          }.to raise_error(ArgumentError, /content or :path/)
        end

        it "raises ArgumentError for both content and path" do
          ActivityNotification.config.mailer_attachments = { filename: 'test.txt', content: 'data', path: '/tmp/test' }
          expect {
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          }.to raise_error(ArgumentError, /only one/)
        end

        it "raises ArgumentError for non-existent path" do
          ActivityNotification.config.mailer_attachments = { filename: 'test.txt', path: '/nonexistent/file.txt' }
          expect {
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          }.to raise_error(ArgumentError, /not found/)
        end

        it "raises ArgumentError for non-Hash spec" do
          ActivityNotification.config.mailer_attachments = "invalid"
          expect {
            ActivityNotification::Mailer.send_notification_email(notification).deliver_now
          }.to raise_error(ArgumentError, /must be a Hash/)
        end
      end

      context "when fallback option is :none and the template is missing" do
        it "raise ActionView::MissingTemplate" do
          expect { ActivityNotification::Mailer.send_notification_email(notification, fallback: :none).deliver_now }
            .to raise_error(ActionView::MissingTemplate)
        end
      end
    end

    context "with deliver_later" do
      it "sends notification email later" do
        expect {
          perform_enqueued_jobs do
            ActivityNotification::Mailer.send_notification_email(notification).deliver_later
          end
        }.to change { ActivityNotification::Mailer.deliveries.size }.by(1)
        expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
      end

      it "sends notification email with active job queue" do
        expect {
            ActivityNotification::Mailer.send_notification_email(notification).deliver_later
        }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
      end
    end
  end

  describe ".send_batch_notification_email" do
    context "with deliver_now" do
      context "as default" do
        before do
          ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_now
        end
  
        it "sends batch notification email now" do
          expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
        end
  
        it "sends to target email" do
          expect(ActivityNotification::Mailer.deliveries.last.to[0]).to eq(test_target.email)
        end
  
      end

      context "with defined mailer_cc in target model" do
        it "sends batch notification email with cc" do
          module BatchTargetCCMethods
            def mailer_cc
              'batch_cc@example.com'
            end
          end
          test_target.extend(BatchTargetCCMethods)
          ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc).not_to be_nil
          expect(ActivityNotification::Mailer.deliveries.last.cc.first)
            .to eq('batch_cc@example.com')
        end

        it "sends batch notification email with multiple cc recipients" do
          module BatchTargetCCArrayMethods
            def mailer_cc
              ['batch_cc1@example.com', 'batch_cc2@example.com']
            end
          end
          test_target.extend(BatchTargetCCArrayMethods)
          ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc)
            .to match_array(['batch_cc1@example.com', 'batch_cc2@example.com'])
        end
      end

      context "without mailer_cc in target model" do
        it "does not send batch notification email with cc" do
          ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_now
          expect(ActivityNotification::Mailer.deliveries.last.cc).to be_nil
        end
      end

      context "with mailer_attachments" do
        after do
          ActivityNotification.config.mailer_attachments = nil
        end

        it "includes attachment in batch email from global config" do
          ActivityNotification.config.mailer_attachments = { filename: 'batch.txt', content: 'batch content' }
          ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_now
          mail = ActivityNotification::Mailer.deliveries.last
          expect(mail.attachments.size).to eq(1)
          expect(mail.attachments.first.filename).to eq('batch.txt')
        end

        it "includes attachment in batch email from target method" do
          module BatchTargetAttachmentMethods
            def mailer_attachments
              { filename: 'target_batch.txt', content: 'target batch' }
            end
          end
          test_target.extend(BatchTargetAttachmentMethods)
          ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_now
          mail = ActivityNotification::Mailer.deliveries.last
          expect(mail.attachments.size).to eq(1)
          expect(mail.attachments.first.filename).to eq('target_batch.txt')
        end
      end

      context "when fallback option is :none and the template is missing" do
        it "raise ActionView::MissingTemplate" do
          expect { ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key, fallback: :none).deliver_now }
            .to raise_error(ActionView::MissingTemplate)
        end
      end
    end

    context "with deliver_later" do
      it "sends notification email later" do
        expect {
          perform_enqueued_jobs do
            ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_later
          end
        }.to change { ActivityNotification::Mailer.deliveries.size }.by(1)
        expect(ActivityNotification::Mailer.deliveries.size).to eq(1)
      end

      it "sends notification email with active job queue" do
        expect {
            ActivityNotification::Mailer.send_batch_notification_email(test_target, notifications, batch_key).deliver_later
        }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
      end
    end
  end
end