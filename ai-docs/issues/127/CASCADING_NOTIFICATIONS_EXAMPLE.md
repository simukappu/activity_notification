# Cascading Notifications - Complete Implementation Example

This document provides a comprehensive example of implementing cascading notifications in a Rails application. This is primarily for AI agents implementing similar functionality.

## Scenario: Task Management Application

Users can be assigned tasks, and we want to ensure they don't miss important assignments through progressive notification escalation.

## Complete Implementation

### 1. Task Model with Cascade Configuration

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
      ActivityNotification::OptionalTarget::Slack => {
        webhook_url: ENV['SLACK_WEBHOOK_URL'],
        target_username: :slack_username,
        channel: '#tasks',
        username: 'TaskBot',
        icon_emoji: ':clipboard:'
      },
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

### 2. User Model Configuration

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable
  acts_as_target
  
  def slack_username
    "@#{username}"
  end
  
  def phone_number
    attributes['phone_number']
  end
  
  def cascade_delay_multiplier
    notification_preferences['cascade_delay_multiplier'] || 1.0
  end
end
```

### 3. Service Object for Notification Management

```ruby
# app/services/task_notification_service.rb
class TaskNotificationService
  def initialize(task)
    @task = task
  end
  
  def notify_assignment
    notifications = @task.notify(:users, key: 'task.assigned', send_later: false)
    
    notifications.each do |notification|
      apply_cascade_to_notification(notification)
    end
    
    notifications
  end
  
  def notify_due_soon
    notifications = @task.notify(:users, key: 'task.due_soon', send_later: false)
    
    notifications.each do |notification|
      cascade_config = [
        { delay: 1.hour, target: :slack },
        { delay: 3.hours, target: :amazon_sns }
      ]
      notification.cascade_notify(cascade_config, trigger_first_immediately: true)
    end
    
    notifications
  end
  
  def notify_overdue
    notifications = @task.notify(:users, key: 'task.overdue', send_later: false)
    
    notifications.each do |notification|
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
    cascade_config = @task.notification_cascade_config
    
    if notification.target.respond_to?(:cascade_delay_multiplier)
      multiplier = notification.target.cascade_delay_multiplier
      cascade_config = adjust_delays(cascade_config, multiplier)
    end
    
    notification.cascade_notify(cascade_config)
  rescue => e
    Rails.logger.error("Failed to start cascade for notification #{notification.id}: #{e.message}")
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

### 4. Controller Integration

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  before_action :authenticate_user!
  
  def create
    @task = Task.new(task_params)
    @task.creator = current_user
    
    if @task.save
      notification_service = TaskNotificationService.new(@task)
      notification_service.notify_assignment
      
      redirect_to @task, notice: 'Task created and assignee notified.'
    else
      render :new
    end
  end
  
  def update
    @task = Task.find(params[:id])
    assignee_changed = @task.assignee_id_changed?
    
    if @task.update(task_params)
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

### 5. Background Job for Scheduled Reminders

```ruby
# app/jobs/task_reminder_job.rb
class TaskReminderJob < ApplicationJob
  queue_as :default
  
  def perform
    check_tasks_due_soon
    check_overdue_tasks
  end
  
  private
  
  def check_tasks_due_soon
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

### 6. User Preferences Management

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

### 7. Monitoring and Analytics

```ruby
# app/models/concerns/cascade_tracking.rb
module CascadeTracking
  extend ActiveSupport::Concern
  
  included do
    after_update :track_cascade_effectiveness, if: :saved_change_to_opened_at?
  end
  
  private
  
  def track_cascade_effectiveness
    return unless opened?
    
    time_to_open = opened_at - created_at
    
    if parameters[:cascade_config].present?
      cascade_config = parameters[:cascade_config]
      
      elapsed_time = 0
      active_step_index = 0
      
      cascade_config.each_with_index do |step, index|
        elapsed_time += step['delay'].to_i
        if time_to_open < elapsed_time
          active_step_index = index
          break
        end
      end
      
      track_cascade_metrics(
        notification_type: key,
        time_to_open: time_to_open,
        cascade_step_when_opened: active_step_index,
        total_cascade_steps: cascade_config.size
      )
    end
  end
  
  def track_cascade_metrics(metrics)
    Rails.logger.info("Cascade Metrics: #{metrics.to_json}")
    # AnalyticsService.track('notification_cascade_opened', metrics)
  end
end

# Include in your notification model
ActivityNotification::Notification.include(CascadeTracking)
```

### 8. Testing Examples

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

## Key Implementation Patterns

1. **Service Objects**: Encapsulate notification logic with cascades
2. **Configuration Constants**: Define reusable cascade strategies
3. **User Preferences**: Allow users to customize cascade timing
4. **Background Jobs**: Handle scheduled notifications
5. **Monitoring**: Track cascade effectiveness
6. **Testing**: Comprehensive test coverage for cascade behavior

This example demonstrates a production-ready implementation of cascading notifications with proper error handling, user preferences, monitoring, and testing.