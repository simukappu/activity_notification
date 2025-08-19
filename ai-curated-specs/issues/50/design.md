# Design Document

## Overview

This design addresses the issue where background email jobs fail when notifications are destroyed before the mailer job executes. The solution involves implementing graceful error handling in the mailer functionality to catch `ActiveRecord::RecordNotFound` exceptions and handle them appropriately.

The core approach is to modify the notification email sending logic to be resilient to missing notifications while maintaining backward compatibility and proper logging.

## Architecture

### Current Flow
1. Notification is created
2. Background job is enqueued to send email
3. Job executes and looks up notification by ID
4. If notification was destroyed, job fails with `ActiveRecord::RecordNotFound`

### Proposed Flow
1. Notification is created
2. Background job is enqueued to send email
3. Job executes and attempts to look up notification by ID
4. If notification is missing:
   - Catch the `ActiveRecord::RecordNotFound` exception
   - Log a warning message with relevant details
   - Complete the job successfully (no re-raise)
5. If notification exists, proceed with normal email sending

## Components and Interfaces

### 1. Mailer Enhancement
**Location**: `app/mailers/activity_notification/mailer.rb`

The mailer's `send_notification_email` method needs to be enhanced to handle missing notifications gracefully.

**Interface Changes**:
- Add rescue block for `ActiveRecord::RecordNotFound`
- Add logging for missing notifications
- Ensure method returns successfully even when notification is missing

### 2. Notification API Enhancement
**Location**: `lib/activity_notification/apis/notification_api.rb`

The notification email sending logic in the API needs to be enhanced to handle cases where the notification record might be missing during job execution.

**Interface Changes**:
- Add resilient notification lookup methods
- Enhance error handling in email sending workflows
- Maintain existing API compatibility

### 3. Job Enhancement
**Location**: Background job classes that send emails

Any background jobs that send notification emails need to handle missing notifications gracefully.

**Interface Changes**:
- Add error handling for missing notifications
- Ensure jobs complete successfully even when notifications are missing
- Add appropriate logging

## Data Models

### Notification Model
No changes to the notification model structure are required. The existing polymorphic associations and dependent_notifications configuration will continue to work as designed.

### Logging Data
New log entries will be created when notifications are missing:
- Log level: WARN
- Message format: "Notification with id [ID] not found for email delivery, likely destroyed before job execution"
- Include relevant context (target, notifiable type, etc.) when available

## Error Handling

### Exception Handling Strategy
1. **Primary Exceptions**: 
   - **ActiveRecord**: `ActiveRecord::RecordNotFound`
   - **Mongoid**: `Mongoid::Errors::DocumentNotFound`
   - **Dynamoid**: `Dynamoid::Errors::RecordNotFound`
2. **Handling Approach**: Catch all ORM-specific exceptions, log appropriately, do not re-raise
3. **Fallback Behavior**: Complete job successfully, no email sent

### Error Recovery
- No automatic retry needed since the notification is intentionally destroyed
- Log warning for monitoring and debugging purposes
- Continue processing other notifications normally

### Error Logging
```ruby
# Example log message format with ORM detection
Rails.logger.warn "ActivityNotification: Notification with id #{notification_id} not found for email delivery (#{orm_name}), likely destroyed before job execution"
```

### ORM-Specific Error Handling
```ruby
# Unified exception handling for all supported ORMs
rescue_from_notification_not_found do |exception|
  log_missing_notification(notification_id, exception.class.name)
end

# ORM-specific rescue blocks
rescue ActiveRecord::RecordNotFound => e
rescue Mongoid::Errors::DocumentNotFound => e  
rescue Dynamoid::Errors::RecordNotFound => e
```

## Testing Strategy

### Multi-ORM Testing Requirements
All tests must pass across all three supported ORMs:
- **ActiveRecord**: `bundle exec rspec`
- **Mongoid**: `AN_ORM=mongoid bundle exec rspec`
- **Dynamoid**: `AN_ORM=dynamoid bundle exec rspec`

### Code Coverage Requirements
- **Target**: 100% code coverage using Coveralls
- **Coverage Scope**: All new code paths and exception handling logic
- **Testing Approach**: Comprehensive test coverage for all ORMs and scenarios

### Unit Tests
1. **Test Missing Notification Handling (All ORMs)**
   - Create notification in each ORM
   - Destroy notification using ORM-specific methods
   - Attempt to send email
   - Verify ORM-specific exception is caught and handled
   - Verify appropriate logging occurs
   - Ensure 100% coverage of exception handling paths

2. **Test Normal Email Flow (All ORMs)**
   - Create notification in each ORM
   - Send email successfully
   - Verify email is sent successfully
   - Verify no error logging occurs
   - Cover all normal execution paths

### Integration Tests
1. **Test with Background Jobs (All ORMs)**
   - Create notifiable with dependent_notifications: :destroy for each ORM
   - Trigger notification creation
   - Destroy notifiable before job executes
   - Verify job completes successfully across all ORMs
   - Verify appropriate logging

2. **Test Rapid Create/Destroy Cycles (All ORMs)**
   - Simulate Like/Unlike scenario for each ORM
   - Create and destroy notifiable rapidly
   - Verify system remains stable across all ORMs
   - Verify no job failures occur

### Test Coverage Areas
- **ActiveRecord ORM implementation** (`bundle exec rspec`)
  - Test `ActiveRecord::RecordNotFound` exception handling
  - Test with ActiveRecord-specific dependent_notifications behavior
  - Ensure 100% coverage of ActiveRecord code paths
- **Mongoid ORM implementation** (`AN_ORM=mongoid bundle exec rspec`)
  - Test `Mongoid::Errors::DocumentNotFound` exception handling
  - Test with Mongoid-specific document destruction behavior
  - Ensure 100% coverage of Mongoid code paths
- **Dynamoid ORM implementation** (`AN_ORM=dynamoid bundle exec rspec`)
  - Test `Dynamoid::Errors::RecordNotFound` exception handling
  - Test with DynamoDB-specific record deletion behavior
  - Ensure 100% coverage of Dynamoid code paths
- **Cross-ORM compatibility**
  - Ensure consistent behavior across all ORMs using all three test commands
  - Test ORM detection and appropriate exception handling
  - Verify 100% coverage across all ORM configurations
- **Different dependent_notifications options** (:destroy, :delete_all, :update_group_and_destroy, etc.)
- **Various notification types and configurations**
- **Coveralls Integration**
  - Ensure all new code paths are covered by tests
  - Maintain 100% code coverage requirement
  - Cover all exception handling branches and logging paths

## Implementation Considerations

### Backward Compatibility
- All existing APIs remain unchanged
- No configuration changes required
- Existing error handling behavior preserved for other error types

### Performance Impact
- Minimal performance impact (only adds exception handling)
- No additional database queries in normal flow
- Logging overhead is minimal

### ORM Compatibility
The solution needs to handle different ORM-specific exceptions and behaviors:

#### ActiveRecord
- **Exception**: `ActiveRecord::RecordNotFound`
- **Behavior**: Standard Rails exception when record not found
- **Implementation**: Direct rescue block for ActiveRecord::RecordNotFound

#### Mongoid  
- **Exception**: `Mongoid::Errors::DocumentNotFound`
- **Behavior**: Mongoid-specific exception for missing documents
- **Implementation**: Rescue block for Mongoid::Errors::DocumentNotFound
- **Considerations**: Mongoid may have different query behavior

#### Dynamoid
- **Exception**: `Dynamoid::Errors::RecordNotFound` 
- **Behavior**: DynamoDB-specific exception for missing records
- **Implementation**: Rescue block for Dynamoid::Errors::RecordNotFound
- **Considerations**: DynamoDB eventual consistency may affect timing

#### Unified Approach
- Create a common exception handling method that works across all ORMs
- Use ActivityNotification.config.orm to detect current ORM
- Implement ORM-specific rescue blocks within a unified interface

### Configuration Options
Consider adding optional configuration for:
- Log level for missing notification warnings
- Whether to log missing notifications at all
- Custom handling callbacks for missing notifications

## Security Considerations

### Information Disclosure
- Log messages should not expose sensitive user data
- Include only necessary identifiers (notification ID, basic type info)
- Avoid logging personal information from notification parameters

### Job Queue Security
- Ensure failed jobs don't expose sensitive information
- Maintain job queue stability and prevent cascading failures

## Monitoring and Observability

### Metrics to Track
- Count of missing notification warnings
- Success rate of email jobs after implementation
- Performance impact of additional error handling

### Alerting Considerations
- High frequency of missing notifications might indicate application issues
- Monitor for patterns that suggest systematic problems
- Alert on unusual spikes in missing notification logs