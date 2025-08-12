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
