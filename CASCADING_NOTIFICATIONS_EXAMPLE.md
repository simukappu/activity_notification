# Cascading Notifications - Example Implementation

This file demonstrates a complete, realistic implementation of cascading notifications
in a Rails application.

## Scenario: Task Management Application

Users can be assigned tasks, and we want to ensure they don't miss important assignments
through progressive notification escalation.

## Step 1: Configure Optional Targets

First, ensure your notifiable model has optional targets configured:

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  belongs_to :assignee, class_name: 'User'
  belongs_to :creator, class_name: 'User'
  
  validates :title, :description, :due_date, presence: true
  
  # Configure as notifiable with optional targets
  require 'activity_notification/optional_targets/slack'
  require 'activity_notification/optional_targets/amazon_sns'
  
  acts_as_notifiable :users,
    targets: ->(task, key) { [task.assignee] },
    notifiable_path: :task_notifiable_path,
    group: :project,
    notifier: :creator,
    optional_targets: {
      # Slack notifications
      ActivityNotification::OptionalTarget::Slack => {
        webhook_url: ENV['SLACK_WEBHOOK_URL'],
        target_username: :slack_username,
        channel: '#tasks',
        username: 'TaskBot',
        icon_emoji: ':clipboard:'
      },
      # SMS via Amazon SNS (optional)
      ActivityNotification::OptionalTarget::AmazonSNS => {
        phone_number: :phone_number
      }
    }
  
  def task_notifiable_path
    Rails.application.routes.url_helpers.task_path(self)
  end
  
  # Define cascade strategies based on task priority
  def notification_cascade_config
    case priority
    when 'urgent'
      URGENT_TASK_CASCADE
    when 'high'
      HIGH_PRIORITY_CASCADE
    when 'normal'
      NORMAL_PRIORITY_CASCADE
    else
      LOW_PRIORITY_CASCADE
    end
  end
  
  # Cascade configurations as constants
  URGENT_TASK_CASCADE = [
    { delay: 2.minutes, target: :slack, options: { channel: '#urgent-tasks' } },
    { delay: 5.minutes, target: :amazon_sns },
    { delay: 15.minutes, target: :slack, options: { channel: '@assignee' } }
  ].freeze
  
  HIGH_PRIORITY_CASCADE = [
    { delay: 10.minutes, target: :slack },
    { delay: 30.minutes, target: :amazon_sns }
  ].freeze
  
  NORMAL_PRIORITY_CASCADE = [
    { delay: 30.minutes, target: :slack },
    { delay: 2.hours, target: :amazon_sns }
  ].freeze
  
  LOW_PRIORITY_CASCADE = [
    { delay: 2.hours, target: :slack },
    { delay: 1.day, target: :amazon_sns }
  ].freeze
end
```

## Step 2: Configure User Model

Ensure users can receive notifications and have the necessary fields:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Devise or other authentication
  devise :database_authenticatable, :registerable

  # ActivityNotification target configuration
  acts_as_target
  
  # Optional target contact information
  # These are referenced by optional targets
  def slack_username
    "@#{username}" # or slack_handle field
  end
  
  def phone_number
    # Format: +1234567890
    attributes['phone_number']
  end
  
  # Allow users to customize their cascade preferences
  def cascade_delay_multiplier
    # User can adjust notification urgency: 0.5 = faster, 2.0 = slower
    notification_preferences['cascade_delay_multiplier'] || 1.0
  end
end
```

## Step 3: Create Service for Notification with Cascade

Create a service object to handle task creation with notifications:

```ruby
# app/services/task_notification_service.rb
class TaskNotificationService
  def initialize(task)
    @task = task
  end
  
  # Create notification with cascade for task assignment
  def notify_assignment
    # Create the notification
    notifications = @task.notify(:users, key: 'task.assigned', send_later: false)
    
    # Apply cascade to each notification
    notifications.each do |notification|
      apply_cascade_to_notification(notification)
    end
    
    notifications
  end
  
  # Create notification with cascade for task due soon
  def notify_due_soon
    notifications = @task.notify(:users, key: 'task.due_soon', send_later: false)
    
    notifications.each do |notification|
      # Use more aggressive cascade for due soon notifications
      cascade_config = [
        { delay: 1.hour, target: :slack },
        { delay: 3.hours, target: :amazon_sns }
      ]
      notification.cascade_notify(cascade_config, trigger_first_immediately: true)
    end
    
    notifications
  end
  
  # Create notification with cascade for overdue tasks
  def notify_overdue
    notifications = @task.notify(:users, key: 'task.overdue', send_later: false)
    
    notifications.each do |notification|
      # Very aggressive cascade for overdue
      cascade_config = [
        { delay: 30.minutes, target: :slack, options: { channel: '#urgent-tasks' } },
        { delay: 1.hour, target: :amazon_sns },
        { delay: 2.hours, target: :slack, options: { channel: '@assignee' } }
      ]
      notification.cascade_notify(cascade_config, trigger_first_immediately: true)
    end
    
    notifications
  end
  
  private
  
  def apply_cascade_to_notification(notification)
    # Get cascade config based on task priority
    cascade_config = @task.notification_cascade_config
    
    # Adjust delays based on user preferences
    if notification.target.respond_to?(:cascade_delay_multiplier)
      multiplier = notification.target.cascade_delay_multiplier
      cascade_config = adjust_delays(cascade_config, multiplier)
    end
    
    # Start the cascade
    notification.cascade_notify(cascade_config)
  rescue => e
    Rails.logger.error("Failed to start cascade for notification #{notification.id}: #{e.message}")
    # Optionally: send alert to monitoring service
  end
  
  def adjust_delays(cascade_config, multiplier)
    cascade_config.map do |step|
      step.dup.tap do |adjusted_step|
        original_delay = adjusted_step[:delay]
        adjusted_step[:delay] = (original_delay.to_i * multiplier).seconds
      end
    end
  end
end
```

## Step 4: Use in Controllers

Integrate the service into your controller:

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  before_action :authenticate_user!
  
  def create
    @task = Task.new(task_params)
    @task.creator = current_user
    
    if @task.save
      # Create notifications with cascade
      notification_service = TaskNotificationService.new(@task)
      notification_service.notify_assignment
      
      redirect_to @task, notice: 'Task created and assignee notified.'
    else
      render :new
    end
  end
  
  def update
    @task = Task.find(params[:id])
    
    # Check if assignee changed
    assignee_changed = @task.assignee_id_changed?
    
    if @task.update(task_params)
      # Notify new assignee if changed
      if assignee_changed
        notification_service = TaskNotificationService.new(@task)
        notification_service.notify_assignment
      end
      
      redirect_to @task, notice: 'Task updated.'
    else
      render :edit
    end
  end
  
  private
  
  def task_params
    params.require(:task).permit(:title, :description, :due_date, :priority, :assignee_id)
  end
end
```

## Step 5: Background Job for Due Date Reminders

Create a scheduled job to check for due tasks:

```ruby
# app/jobs/task_reminder_job.rb
class TaskReminderJob < ApplicationJob
  queue_as :default
  
  # Run this job periodically (e.g., every hour with cron)
  def perform
    check_tasks_due_soon
    check_overdue_tasks
  end
  
  private
  
  def check_tasks_due_soon
    # Tasks due in next 24 hours that haven't been notified recently
    tasks = Task.where(completed: false)
                .where('due_date BETWEEN ? AND ?', Time.current, 24.hours.from_now)
                .where('last_reminder_sent_at IS NULL OR last_reminder_sent_at < ?', 12.hours.ago)
    
    tasks.each do |task|
      notification_service = TaskNotificationService.new(task)
      notification_service.notify_due_soon
      task.update_column(:last_reminder_sent_at, Time.current)
    end
  end
  
  def check_overdue_tasks
    # Overdue tasks that haven't been notified recently
    tasks = Task.where(completed: false)
                .where('due_date < ?', Time.current)
                .where('last_overdue_reminder_at IS NULL OR last_overdue_reminder_at < ?', 6.hours.ago)
    
    tasks.each do |task|
      notification_service = TaskNotificationService.new(task)
      notification_service.notify_overdue
      task.update_column(:last_overdue_reminder_at, Time.current)
    end
  end
end
```

## Step 6: Configure Routes

Add notification routes for your users:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # ... other routes
  
  # Activity notification routes for users
  notify_to :users
  
  resources :tasks do
    member do
      post :complete
      post :snooze_notifications
    end
  end
end
```

## Step 7: Add User Preferences

Allow users to control notification cascades:

```ruby
# app/controllers/notification_preferences_controller.rb
class NotificationPreferencesController < ApplicationController
  before_action :authenticate_user!
  
  def edit
    @preferences = current_user.notification_preferences || {}
  end
  
  def update
    preferences = current_user.notification_preferences || {}
    preferences.merge!(preferences_params)
    
    if current_user.update(notification_preferences: preferences)
      redirect_to edit_notification_preferences_path, 
                  notice: 'Notification preferences updated.'
    else
      render :edit
    end
  end
  
  private
  
  def preferences_params
    params.require(:notification_preferences).permit(
      :cascade_delay_multiplier,
      :enable_slack_notifications,
      :enable_sms_notifications,
      :quiet_hours_start,
      :quiet_hours_end
    )
  end
end
```

```erb
<!-- app/views/notification_preferences/edit.html.erb -->
<h1>Notification Preferences</h1>

<%= form_with model: @preferences, 
              url: notification_preferences_path,
              local: true do |f| %>
  
  <div class="field">
    <%= f.label :cascade_delay_multiplier, "Notification Urgency" %>
    <%= f.select :cascade_delay_multiplier, 
                 options_for_select([
                   ["More Urgent (Faster notifications)", 0.5],
                   ["Normal", 1.0],
                   ["Less Urgent (Slower notifications)", 2.0],
                   ["Minimal (Much slower)", 3.0]
                 ], @preferences[:cascade_delay_multiplier] || 1.0) %>
    <small>Controls how quickly notifications escalate to other channels</small>
  </div>
  
  <div class="field">
    <%= f.check_box :enable_slack_notifications %>
    <%= f.label :enable_slack_notifications, "Enable Slack Notifications" %>
  </div>
  
  <div class="field">
    <%= f.check_box :enable_sms_notifications %>
    <%= f.label :enable_sms_notifications, "Enable SMS Notifications" %>
  </div>
  
  <%= f.submit "Save Preferences", class: "btn btn-primary" %>
<% end %>
```

## Step 8: Monitor and Track

Add monitoring to track cascade effectiveness:

```ruby
# app/models/concerns/cascade_tracking.rb
module CascadeTracking
  extend ActiveSupport::Concern
  
  included do
    # Add callbacks to track when notifications are opened
    after_update :track_cascade_effectiveness, if: :saved_change_to_opened_at?
  end
  
  private
  
  def track_cascade_effectiveness
    return unless opened?
    
    # Calculate time to open
    time_to_open = opened_at - created_at
    
    # Track which cascade step was active when opened
    # (This requires storing cascade config in notification parameters)
    if parameters[:cascade_config].present?
      cascade_config = parameters[:cascade_config]
      
      # Determine which step was active
      elapsed_time = 0
      active_step_index = 0
      
      cascade_config.each_with_index do |step, index|
        elapsed_time += step['delay'].to_i
        if time_to_open < elapsed_time
          active_step_index = index
          break
        end
      end
      
      # Log to analytics
      track_cascade_metrics(
        notification_type: key,
        time_to_open: time_to_open,
        cascade_step_when_opened: active_step_index,
        total_cascade_steps: cascade_config.size
      )
    end
  end
  
  def track_cascade_metrics(metrics)
    # Send to your analytics service (e.g., Mixpanel, Segment, custom)
    Rails.logger.info("Cascade Metrics: #{metrics.to_json}")
    # AnalyticsService.track('notification_cascade_opened', metrics)
  end
end

# Include in your notification model
# In config/initializers/activity_notification.rb or notification.rb
ActivityNotification::Notification.include(CascadeTracking)
```

## Step 9: Testing

Create comprehensive tests:

```ruby
# spec/services/task_notification_service_spec.rb
require 'rails_helper'

RSpec.describe TaskNotificationService do
  let(:creator) { create(:user) }
  let(:assignee) { create(:user) }
  let(:task) { create(:task, creator: creator, assignee: assignee, priority: 'urgent') }
  let(:service) { described_class.new(task) }
  
  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end
  
  describe '#notify_assignment' do
    it 'creates notification with cascade' do
      notifications = service.notify_assignment
      
      expect(notifications.size).to eq(1)
      expect(notifications.first.target).to eq(assignee)
    end
    
    it 'enqueues cascade jobs' do
      expect {
        service.notify_assignment
      }.to have_enqueued_job(ActivityNotification::CascadingNotificationJob)
    end
    
    it 'uses urgent cascade for urgent tasks' do
      notification = service.notify_assignment.first
      
      # Verify cascade was started
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to be > 0
    end
  end
  
  describe '#notify_due_soon' do
    it 'creates notification with aggressive cascade' do
      notifications = service.notify_due_soon
      
      expect(notifications.size).to eq(1)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to be > 0
    end
  end
end
```

## Step 10: Documentation for Your Team

Create internal documentation:

```markdown
# Task Notification System

## Overview
Tasks use cascading notifications to ensure assignees see their assignments.

## Cascade Strategies

### Urgent Tasks
- Immediately: In-app notification
- After 2 minutes: Slack (#urgent-tasks)
- After 5 minutes: SMS
- After 15 minutes: Direct Slack message

### High Priority Tasks
- Immediately: In-app notification
- After 10 minutes: Slack
- After 30 minutes: SMS

### Normal Priority Tasks
- Immediately: In-app notification
- After 30 minutes: Slack
- After 2 hours: SMS

### Low Priority Tasks
- Immediately: In-app notification
- After 2 hours: Slack
- After 1 day: SMS

## User Preferences
Users can adjust cascade timing with urgency multiplier:
- 0.5: Faster (50% faster escalation)
- 1.0: Normal
- 2.0: Slower (100% slower escalation)
- 3.0: Much slower (200% slower escalation)

## Monitoring
- Check Rails logs for "Cascade Metrics" entries
- Monitor ActiveJob queue for CascadingNotificationJob
- Track notification open rates by cascade step
```

## Summary

This example demonstrates:
1. ✅ Configuring optional targets on notifiable models
2. ✅ Creating service objects to manage notifications with cascades
3. ✅ Defining cascade strategies based on business logic (priority)
4. ✅ Integrating cascades into controllers
5. ✅ Using background jobs for scheduled notifications
6. ✅ Allowing user preferences for cascade timing
7. ✅ Monitoring and tracking cascade effectiveness
8. ✅ Testing cascade behavior
9. ✅ Documenting the system for your team

This complete implementation can be adapted to your specific use case!
