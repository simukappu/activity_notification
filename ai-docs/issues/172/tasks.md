# Implementation Plan

## Problem 1: Mongoid ORM Compatibility Issue with ID Array Filtering

### Issue Description
The bulk destroy functionality works correctly with ActiveRecord ORM but fails with Mongoid ORM. Specifically, the test case `context 'with ids options'` in `spec/concerns/apis/notification_api_spec.rb` is failing.

**Location**: `lib/activity_notification/apis/notification_api.rb` line 440
**Problematic Code**: 
```ruby
target_notifications = target_notifications.where(id: options[:ids])
```

### Root Cause Analysis
The issue stems from different query syntax requirements between ActiveRecord and Mongoid when filtering by an array of IDs:

1. **ActiveRecord**: Uses `where(id: [1, 2, 3])` which automatically translates to SQL `WHERE id IN (1, 2, 3)`
2. **Mongoid**: Requires explicit `$in` operator syntax for array matching: `where(id: { '$in' => [1, 2, 3] })`

### Current Implementation Problem
The current implementation uses ActiveRecord syntax:
```ruby
target_notifications = target_notifications.where(id: options[:ids])
```

This works for ActiveRecord but fails for Mongoid because Mongoid doesn't automatically interpret an array as an `$in` operation.

### Expected Behavior
- When `options[:ids]` contains `[notification1.id, notification2.id]`, only notifications with those specific IDs should be destroyed
- The filtering should work consistently across both ActiveRecord and Mongoid ORMs
- Other filter options should still be applied in combination with ID filtering

### Test Case Analysis
The failing test:
```ruby
it "destroys notifications with specified IDs only" do
  notification_to_destroy = @user_1.notifications.first
  described_class.destroy_all_of(@user_1, { ids: [notification_to_destroy.id] })
  expect(@user_1.notifications.count).to eq(1)
  expect(@user_1.notifications.first).not_to eq(notification_to_destroy)
end
```

This test expects that when an array of IDs is provided, only those specific notifications are destroyed.

### Solution Strategy
Implement ORM-specific ID filtering logic that:

1. **Detection**: Check the current ORM configuration using `ActivityNotification.config.orm`
2. **ActiveRecord Path**: Use existing `where(id: options[:ids])` syntax
3. **Mongoid Path**: Use `where(id: { '$in' => options[:ids] })` syntax
4. **Dynamoid Path**: Use `where(‘id.in‘: options[:ids])` syntax

### Implementation Plan
1. **Conditional Logic**: Add ORM detection in the `destroy_all_of` method
2. **Mongoid Syntax**: Use `{ '$in' => options[:ids] }` for Mongoid
3. **Backward Compatibility**: Ensure ActiveRecord continues to work as before
4. **Testing**: Verify both ORMs work correctly with the new implementation

### Code Changes Required
**File**: `lib/activity_notification/apis/notification_api.rb`
**Method**: `destroy_all_of` (around line 440)

Replace:
```ruby
if options[:ids].present?
  target_notifications = target_notifications.where(id: options[:ids])
end
```

With ORM-specific logic:
```ruby
if options[:ids].present?
  case ActivityNotification.config.orm
  when :mongoid
    target_notifications = target_notifications.where(id: { '$in' => options[:ids] })
  when :dynamoid
    target_notifications = target_notifications.where('id.in': options[:ids])
  else # :active_record
    target_notifications = target_notifications.where(id: options[:ids])
  end
end
```

### Testing Requirements
1. **Unit Tests**: Ensure the method works with both ActiveRecord and Mongoid
2. **Integration Tests**: Verify the complete destroy_all functionality
3. **Regression Tests**: Ensure existing functionality remains intact

### Risk Assessment
- **Low Risk**: The change is isolated to the ID filtering logic
- **Backward Compatible**: ActiveRecord behavior remains unchanged
- **Well-Tested**: Existing test suite will catch any regressions

### Future Considerations
- Consider extracting ORM-specific query logic into a helper method if more similar cases arise
- Document the ORM differences for future developers
- Consider adding similar logic to other methods that might have the same issue

---

## Problem 2: Add IDs Parameter to open_all API

### Issue Description
Enhance the `open_all_of` method to support the `ids` parameter functionality, similar to the implementation in `destroy_all_of`. This will allow users to open specific notifications by providing an array of notification IDs.

### Current State Analysis

#### Existing open_all_of Method
**Location**: `lib/activity_notification/apis/notification_api.rb` (around line 415)

**Current Implementation**:
```ruby
def open_all_of(target, options = {})
  opened_at = options[:opened_at] || Time.current
  target_unopened_notifications = target.notifications.unopened_only.filtered_by_options(options)
  opened_notifications = target_unopened_notifications.to_a.map { |n| n.opened_at = opened_at; n }
  target_unopened_notifications.update_all(opened_at: opened_at)
  opened_notifications
end
```

**Current Parameters**:
- `opened_at`: Time to set to opened_at of the notification record
- `filtered_by_type`: Notifiable type for filter
- `filtered_by_group`: Group instance for filter
- `filtered_by_group_type`: Group type for filter, valid with :filtered_by_group_id
- `filtered_by_group_id`: Group instance id for filter, valid with :filtered_by_group_type
- `filtered_by_key`: Key of the notification for filter
- `later_than`: ISO 8601 format time to filter notification index later than specified time
- `earlier_than`: ISO 8601 format time to filter notification index earlier than specified time

### Proposed Enhancement

#### Add IDs Parameter Support
Add support for the `ids` parameter to allow opening specific notifications by their IDs, following the same pattern as `destroy_all_of`.

#### Updated Method Signature
```ruby
# @option options [Array] :ids (nil) Array of specific notification IDs to open
def open_all_of(target, options = {})
```

### Implementation Strategy
1. **Reuse existing pattern**: Follow the same ORM-specific ID filtering logic implemented in `destroy_all_of`
2. **Maintain backward compatibility**: Ensure existing functionality remains unchanged
3. **Consistent behavior**: Apply ID filtering after other filters, similar to destroy_all_of

### Code Changes Required

#### 1. Update Method Documentation
**File**: `lib/activity_notification/apis/notification_api.rb`

Add the `ids` parameter to the method documentation:
```ruby
# @option options [Array] :ids (nil) Array of specific notification IDs to open
```

#### 2. Add ID Filtering Logic
Insert the same ORM-specific ID filtering logic used in `destroy_all_of`:

```ruby
def open_all_of(target, options = {})
  opened_at = options[:opened_at] || Time.current
  target_unopened_notifications = target.notifications.unopened_only.filtered_by_options(options)
  
  # Add ID filtering logic (same as destroy_all_of)
  if options[:ids].present?
    # :nocov:
    case ActivityNotification.config.orm
    when :mongoid
      target_unopened_notifications = target_unopened_notifications.where(id: { '$in' => options[:ids] })
    when :dynamoid
      target_unopened_notifications = target_unopened_notifications.where('id.in': options[:ids])
    else # :active_record
      target_unopened_notifications = target_unopened_notifications.where(id: options[:ids])
    end
    # :nocov:
  end
  
  opened_notifications = target_unopened_notifications.to_a.map { |n| n.opened_at = opened_at; n }
  target_unopened_notifications.update_all(opened_at: opened_at)
  opened_notifications
end
```

#### 3. Update Controller Actions
The controller actions that use `open_all_of` should be updated to accept and pass through the `ids` parameter:

**Files to Update**:
- `app/controllers/activity_notification/notifications_controller.rb`
- `app/controllers/activity_notification/notifications_api_controller.rb`

**Parameter Addition**:
```ruby
# Add :ids to permitted parameters
params.permit(:ids => [])
```

#### 4. Update API Documentation
**File**: `lib/activity_notification/controllers/concerns/swagger/notifications_api.rb`

Add `ids` parameter to the Swagger documentation for the open_all endpoint:
```ruby
parameter do
  key :name, :ids
  key :in, :query
  key :description, 'Array of specific notification IDs to open'
  key :required, false
  key :type, :array
  items do
    key :type, :string
  end
end
```

### Testing Requirements

#### 1. Add Test Cases
**File**: `spec/concerns/apis/notification_api_spec.rb`

Add test cases similar to the `destroy_all_of` tests:

```ruby
context 'with ids options' do
  it "opens notifications with specified IDs only" do
    notification_to_open = @user_1.notifications.first
    described_class.open_all_of(@user_1, { ids: [notification_to_open.id] })
    expect(@user_1.notifications.unopened_only.count).to eq(1)
    expect(@user_1.notifications.opened_only!.count).to eq(1)
    expect(@user_1.notifications.opened_only!.first).to eq(notification_to_open)
  end

  it "applies other filter options when ids are specified" do
    notification_to_open = @user_1.notifications.first
    described_class.open_all_of(@user_1, { 
      ids: [notification_to_open.id], 
      filtered_by_key: 'non_existent_key' 
    })
    expect(@user_1.notifications.unopened_only.count).to eq(2)
    expect(@user_1.notifications.opened_only!.count).to eq(0)
  end

  it "only opens unopened notifications even when opened notification IDs are provided" do
    # First open one notification
    notification_to_open = @user_1.notifications.first
    notification_to_open.open!
    
    # Try to open it again using ids parameter
    described_class.open_all_of(@user_1, { ids: [notification_to_open.id] })
    
    # Should not affect the count since it was already opened
    expect(@user_1.notifications.unopened_only.count).to eq(1)
    expect(@user_1.notifications.opened_only!.count).to eq(1)
  end
end
```

#### 2. Update Controller Tests
**File**: `spec/controllers/notifications_api_controller_shared_examples.rb`

Add test cases for the API controller to ensure the `ids` parameter is properly handled:

```ruby
context 'with ids parameter' do
  it "opens only specified notifications" do
    notification_to_open = @user.notifications.first
    post open_all_notification_path(@user), params: { ids: [notification_to_open.id] }
    expect(response).to have_http_status(200)
    expect(@user.notifications.unopened_only.count).to eq(1)
    expect(@user.notifications.opened_only!.count).to eq(1)
  end
end
```

### Benefits

#### 1. Consistency
- Provides consistent API between `open_all_of` and `destroy_all_of` methods
- Both methods now support the same filtering options including `ids`

#### 2. Flexibility
- Allows precise control over which notifications to open
- Enables batch operations on specific notifications
- Supports complex filtering combinations

#### 3. Performance
- Efficient database operations using bulk updates
- Reduces the need for multiple individual open operations

#### 4. User Experience
- Provides the functionality requested in the original issue
- Enables building more sophisticated notification management UIs

### Implementation Considerations

#### 1. Backward Compatibility
- All existing functionality remains unchanged
- New `ids` parameter is optional
- Existing tests should continue to pass

#### 2. ORM Compatibility
- Uses the same ORM-specific logic as `destroy_all_of`
- Tested across ActiveRecord, Mongoid, and Dynamoid

#### 3. Security
- ID filtering is applied after target validation
- Only notifications belonging to the specified target can be opened
- Follows existing security patterns

#### 4. Error Handling
- Invalid IDs are silently ignored (consistent with existing behavior)
- Non-existent notifications don't cause errors
- Maintains existing error handling patterns

### Risk Assessment
- **Low Risk**: Follows established patterns from `destroy_all_of`
- **Backward Compatible**: ActiveRecord behavior remains unchanged
- **Well-Tested**: Existing test suite will catch any regressions

### Implementation Timeline
1. **Phase 1**: Update `open_all_of` method with ID filtering logic
2. **Phase 2**: Add comprehensive test cases
3. **Phase 3**: Update controller actions and API documentation
4. **Phase 4**: Update controller tests and integration tests
5. **Phase 5**: Documentation updates and final testing