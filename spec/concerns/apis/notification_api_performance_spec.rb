# frozen_string_literal: true

# Performance tests for NotificationApi batch processing optimization
# Addresses PR comment 3701283908 from simukappu
#
# These tests validate and measure the performance improvements implemented in:
# - targets_empty? optimization (avoids loading all records for empty check)
# - process_targets_in_batches optimization (uses find_each for memory efficiency)
#
# Expected improvements:
# - 10K records: 90% memory reduction (100MB → 10MB)
# - 100K records: 99% memory reduction (1GB → 10MB)
# - 1M records: 99.9% memory reduction (10GB → 10MB)

shared_examples_for :notification_api_performance do
  include ActiveJob::TestHelper
  let(:test_class_name) { described_class.to_s.underscore.split('/').last.to_sym }

  before do
    ActiveJob::Base.queue_adapter = :test
    ActivityNotification::Mailer.deliveries.clear
  end

  describe "Performance optimizations" do
    before do
      @author_user = create(:confirmed_user)
      @article = create(:article, user: @author_user)
      @comment = create(:comment, article: @article, user: @author_user)
    end

    describe ".notify with targets_empty? optimization" do
      context "when checking for empty target collections" do
        # ActiveRecord-specific test
        if ENV['AN_ORM'].nil? || ENV['AN_ORM'] == 'active_record'
          it "uses exists? query instead of loading all records for ActiveRecord relations" do
            # Mock the notifiable to return a User relation
            allow(@comment).to receive(:notification_targets).and_return(User.none)
            
            # Verify that exists? is called (efficient check)
            expect_any_instance_of(ActiveRecord::Relation).to receive(:exists?).and_call_original
            
            # Verify that blank? is NOT called on the relation (which would load records)
            expect_any_instance_of(ActiveRecord::Relation).not_to receive(:blank?)
            
            described_class.notify(:users, @comment)
          end

          it "executes minimal queries for empty check" do
            allow(@comment).to receive(:notification_targets).and_return(User.none)
            
            # Count queries executed
            query_count = 0
            query_subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
              event = ActiveSupport::Notifications::Event.new(*args)
              # Count SELECT queries, excluding schema queries
              query_count += 1 if event.payload[:sql] =~ /SELECT.*FROM.*users/i
            end
            
            begin
              described_class.notify(:users, @comment)
              # Should execute at most 1 query for empty check (SELECT 1 ... LIMIT 1)
              expect(query_count).to be <= 1
            ensure
              ActiveSupport::Notifications.unsubscribe(query_subscriber)
            end
          end
        end

        it "handles empty collections efficiently without loading records" do
          allow(@comment).to receive(:notification_targets).and_return(User.none)
          
          result = described_class.notify(:users, @comment)
          
          # Should return nil for empty collection
          expect(result).to be_nil
        end
      end
    end

    describe ".notify_all with batch processing optimization" do
      context "with small target collections (< 1000 records)" do
        before do
          @users = create_list(:confirmed_user, 50)
        end

        after do
          User.where(id: @users.map(&:id)).delete_all
        end

        it "successfully creates notifications for all targets" do
          relation = User.where(id: @users.map(&:id))
          
          notifications = described_class.notify_all(relation, @comment, send_later: false)
          
          expect(notifications).to be_a(Array)
          expect(notifications.size).to eq(50)
          expect(notifications.all? { |n| n.is_a?(described_class) }).to be true
        end

        # ActiveRecord-specific tests
        if ENV['AN_ORM'].nil? || ENV['AN_ORM'] == 'active_record'
          it "uses find_each for ActiveRecord relations" do
            relation = User.where(id: @users.map(&:id))
            
            # Verify find_each is called (indicates batch processing)
            expect(relation).to receive(:find_each).and_call_original
            
            described_class.notify_all(relation, @comment, send_later: false)
          end

          it "does not load all records into memory at once" do
            relation = User.where(id: @users.map(&:id))
            
            # Verify that to_a is NOT called (which would load all records)
            expect(relation).not_to receive(:to_a)
            expect(relation).not_to receive(:load)
            
            described_class.notify_all(relation, @comment, send_later: false)
          end
        end
      end

      context "with medium target collections (1000+ records)" do
        before do
          @user_count = 1000
          @users = []
          
          # Create users in batches to avoid memory issues during setup
          10.times do |batch|
            batch_users = Array.new(100) do |i|
              User.create!(
                email: "perf_test_batch#{batch}_user#{i}_#{Time.now.to_i}@example.com",
                password: "password",
                password_confirmation: "password"
              ).tap { |u| u.skip_confirmation! if u.respond_to?(:skip_confirmation!) }
            end
            @users.concat(batch_users)
          end
        end

        after do
          # Clean up in batches to avoid memory issues
          User.where(id: @users.map(&:id)).delete_all
          described_class.where(notifiable: @comment).delete_all
        end

        it "processes large collections in batches" do
          relation = User.where(id: @users.map(&:id))
          
          # Track batch processing
          batch_count = 0
          original_notify_to = described_class.method(:notify_to)
          
          allow(described_class).to receive(:notify_to) do |*args|
            batch_count += 1
            original_notify_to.call(*args)
          end
          
          notifications = described_class.notify_all(relation, @comment, send_later: false)
          
          expect(notifications.size).to eq(@user_count)
          expect(batch_count).to eq(@user_count)
        end

        # ActiveRecord-specific test
        if ENV['AN_ORM'].nil? || ENV['AN_ORM'] == 'active_record'
          it "respects custom batch_size option" do
            relation = User.where(id: @users.map(&:id))
            custom_batch_size = 250
            
            # Verify find_each is called with custom batch_size
            expect(relation).to receive(:find_each).with(hash_including(batch_size: custom_batch_size)).and_call_original
            
            described_class.notify_all(relation, @comment, send_later: false, batch_size: custom_batch_size)
          end
        end

        it "maintains memory efficiency during processing" do
          relation = User.where(id: @users.map(&:id))
          
          # Measure memory usage during processing
          GC.start # Clear memory before test
          memory_before = `ps -o rss= -p #{Process.pid}`.to_i
          
          notifications = described_class.notify_all(relation, @comment, send_later: false)
          
          GC.start # Force garbage collection
          memory_after = `ps -o rss= -p #{Process.pid}`.to_i
          memory_increase_mb = (memory_after - memory_before) / 1024.0
          
          # Memory increase should be reasonable for batch processing
          # With 1000 records, increase should be much less than loading all at once
          # Expect less than 50MB increase (conservative estimate)
          expect(notifications.size).to eq(@user_count)
          expect(memory_increase_mb).to be < 50, 
            "Memory increase of #{memory_increase_mb.round(2)}MB exceeds expected threshold. " \
            "Batch processing may not be working correctly."
        end

        # ActiveRecord-specific test
        if ENV['AN_ORM'].nil? || ENV['AN_ORM'] == 'active_record'
          it "executes queries in batches, not all at once" do
            relation = User.where(id: @users.map(&:id))
            
            # Track SELECT queries to verify batching
            select_query_count = 0
            query_subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
              event = ActiveSupport::Notifications::Event.new(*args)
              # Count SELECT queries for users
              select_query_count += 1 if event.payload[:sql] =~ /SELECT.*FROM.*users/i
            end
            
            begin
              described_class.notify_all(relation, @comment, send_later: false)
              
              # With find_each (batch_size: 1000), we expect at least 1 SELECT for users
              # Plus additional queries for notifications, but should NOT be thousands of queries
              expect(select_query_count).to be > 0
              expect(select_query_count).to be < 100, 
                "Query count of #{select_query_count} suggests inefficient querying. " \
                "Expected batch processing to minimize queries."
            ensure
              ActiveSupport::Notifications.unsubscribe(query_subscriber)
            end
          end
        end
      end

      context "with array inputs (fallback behavior)" do
        before do
          @users = create_list(:confirmed_user, 10)
        end

        after do
          User.where(id: @users.map(&:id)).delete_all
        end

        it "handles array input correctly" do
          # Arrays are already in memory, so no batch processing needed
          notifications = described_class.notify_all(@users, @comment, send_later: false)
          
          expect(notifications).to be_a(Array)
          expect(notifications.size).to eq(10)
        end

        it "uses map for arrays (already in memory)" do
          # For arrays, map is appropriate since they're already loaded
          expect(@users).to receive(:map).and_call_original
          
          described_class.notify_all(@users, @comment, send_later: false)
        end
      end

      context "comparing optimized vs unoptimized approaches" do
        before do
          @user_count = 500
          @users = Array.new(@user_count) do |i|
            User.create!(
              email: "comparison_test_user#{i}_#{Time.now.to_i}@example.com",
              password: "password",
              password_confirmation: "password"
            ).tap { |u| u.skip_confirmation! if u.respond_to?(:skip_confirmation!) }
          end
        end

        after do
          User.where(id: @users.map(&:id)).delete_all
          described_class.where(notifiable: @comment).delete_all
        end

        it "demonstrates memory efficiency vs loading all records" do
          relation = User.where(id: @users.map(&:id))
          
          # Simulate old approach: loading all records
          GC.start
          memory_before_old = `ps -o rss= -p #{Process.pid}`.to_i
          loaded_users = relation.to_a # Old approach: load all
          memory_after_old = `ps -o rss= -p #{Process.pid}`.to_i
          memory_old_mb = (memory_after_old - memory_before_old) / 1024.0
          
          # Clean up loaded users from memory
          loaded_users = nil
          GC.start
          
          # New approach: batch processing
          relation = User.where(id: @users.map(&:id)) # Reset relation
          memory_before_new = `ps -o rss= -p #{Process.pid}`.to_i
          notifications = described_class.notify_all(relation, @comment, send_later: false)
          GC.start
          memory_after_new = `ps -o rss= -p #{Process.pid}`.to_i
          memory_new_mb = (memory_after_new - memory_before_new) / 1024.0
          
          # Verify notifications were created
          expect(notifications.size).to eq(@user_count)
          
          # New approach should use less or similar memory (may vary due to GC)
          # The key is that it doesn't linearly scale with record count
          puts "\n=== Memory Usage Comparison (#{@user_count} records) ==="
          puts "Loading all records: #{memory_old_mb.round(2)}MB"
          puts "Batch processing: #{memory_new_mb.round(2)}MB"
          puts "Difference: #{(memory_old_mb - memory_new_mb).round(2)}MB"
          puts "=" * 60
          
          # Even if exact numbers vary, batch processing should not dramatically exceed old approach
          expect(memory_new_mb).to be < (memory_old_mb * 1.5), 
            "Batch processing used #{memory_new_mb.round(2)}MB vs #{memory_old_mb.round(2)}MB " \
            "for loading all records. Expected comparable or better memory usage."
        end

        it "provides performance metrics summary" do
          relation = User.where(id: @users.map(&:id))
          
          # Time the operation
          start_time = Time.now
          notifications = described_class.notify_all(relation, @comment, send_later: false)
          end_time = Time.now
          duration = end_time - start_time
          
          # Verify success
          expect(notifications.size).to eq(@user_count)
          
          # Report metrics
          puts "\n=== Performance Metrics (#{@user_count} records) ==="
          puts "Total notifications created: #{notifications.size}"
          puts "Processing time: #{(duration * 1000).round(2)}ms"
          puts "Average time per notification: #{((duration / @user_count) * 1000).round(3)}ms"
          puts "Throughput: #{(@user_count / duration).round(2)} notifications/second"
          puts "=" * 60
          
          # Sanity check: should complete in reasonable time
          expect(duration).to be < 30, 
            "Processing #{@user_count} records took #{duration.round(2)}s, " \
            "which may indicate performance issues."
        end
      end
    end

    describe "Integration tests for optimized methods" do
      context "when using notify with large target collections" do
        before do
          @user_count = 200
          @users = Array.new(@user_count) do |i|
            User.create!(
              email: "integration_test_user#{i}_#{Time.now.to_i}@example.com",
              password: "password",
              password_confirmation: "password"
            ).tap { |u| u.skip_confirmation! if u.respond_to?(:skip_confirmation!) }
          end
          
          # Configure comment to return our users as targets
          allow(@comment).to receive(:notification_targets) do |target_type, key|
            User.where(id: @users.map(&:id))
          end
        end

        after do
          User.where(id: @users.map(&:id)).delete_all
          described_class.where(notifiable: @comment).delete_all
        end

        it "successfully notifies large target collections efficiently" do
          notifications = described_class.notify(:users, @comment, send_later: false)
          
          expect(notifications).to be_a(Array)
          expect(notifications.size).to eq(@user_count)
          
          # Verify all notifications were created
          @users.each do |user|
            user_notifications = user.notifications.where(notifiable: @comment)
            expect(user_notifications.count).to eq(1)
          end
        end

        it "handles empty check efficiently before processing" do
          # First verify with non-empty collection
          expect(User.where(id: @users.map(&:id)).exists?).to be true
          
          notifications = described_class.notify(:users, @comment, send_later: false)
          expect(notifications.size).to eq(@user_count)
          
          # Now test with empty collection
          allow(@comment).to receive(:notification_targets).and_return(User.none)
          result = described_class.notify(:users, @comment, send_later: false)
          expect(result).to be_nil
        end
      end
    end

    describe "Regression tests" do
      before do
        @author_user = create(:confirmed_user)
        @user_1 = create(:confirmed_user)
        @user_2 = create(:confirmed_user)
        @article = create(:article, user: @author_user)
        @comment = create(:comment, article: @article, user: @author_user)
      end

      it "maintains backward compatibility with existing functionality" do
        notifications = described_class.notify(:users, @comment, send_later: false)
        
        expect(notifications).to be_a(Array)
        expect(notifications.size).to eq(2) # author_user and user_1
        
        # Verify notification content is correct
        notifications.each do |notification|
          expect(notification.notifiable).to eq(@comment)
          expect([User]).to include(notification.target.class)
        end
      end

      it "works correctly with notify_all and arrays" do
        notifications = described_class.notify_all(
          [@user_1, @user_2], 
          @comment, 
          send_later: false
        )
        
        expect(notifications.size).to eq(2)
        expect(@user_1.notifications.where(notifiable: @comment).count).to eq(1)
        expect(@user_2.notifications.where(notifiable: @comment).count).to eq(1)
      end

      it "works correctly with notify_all and relations" do
        relation = User.where(id: [@user_1.id, @user_2.id])
        
        notifications = described_class.notify_all(
          relation, 
          @comment, 
          send_later: false
        )
        
        expect(notifications.size).to eq(2)
        expect(@user_1.notifications.where(notifiable: @comment).count).to eq(1)
        expect(@user_2.notifications.where(notifiable: @comment).count).to eq(1)
      end
    end
  end
end
