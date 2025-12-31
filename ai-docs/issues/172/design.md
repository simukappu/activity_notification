# Design Document: Bulk destroy notifications API

## Issue Summary
GitHub Issue [#172](https://github.com/simukappu/activity_notification/issues/172) requests the ability to delete more than one notification for a target. Currently, only single notification deletion is available through the `destroy` API. The user wants a `bulk_destroy` API or provision to create custom APIs for bulk destroying notifications.

## Current State Analysis

### Existing Destroy Functionality
- **Single Destroy**: `DELETE /:target_type/:target_id/notifications/:id`
  - Implemented in `NotificationsController#destroy`
  - API version in `NotificationsApiController#destroy`
  - Simply calls `@notification.destroy` on individual notification

### Existing Bulk Operations Pattern
- **Bulk Open**: `POST /:target_type/:target_id/notifications/open_all`
  - Implemented in `NotificationsController#open_all`
  - Uses `@target.open_all_notifications(params)` 
  - Backend implementation in `NotificationApi#open_all_of`
  - Uses `update_all(opened_at: opened_at)` for efficient bulk updates

## Proposed Implementation

### 1. Backend API Method (NotificationApi)
**File**: `lib/activity_notification/apis/notification_api.rb`

Add a new class method `destroy_all_of` following the pattern of `open_all_of`:

```ruby
# Destroys all notifications of the target matching the filter criteria.
#
# @param [Object] target Target of the notifications to destroy
# @param [Hash] options Options for filtering notifications to destroy
# @option options [String]   :filtered_by_type       (nil) Notifiable type for filter
# @option options [Object]   :filtered_by_group      (nil) Group instance for filter  
# @option options [String]   :filtered_by_group_type (nil) Group type for filter, valid with :filtered_by_group_id
# @option options [String]   :filtered_by_group_id   (nil) Group instance id for filter, valid with :filtered_by_group_type
# @option options [String]   :filtered_by_key        (nil) Key of the notification for filter
# @option options [String]   :later_than             (nil) ISO 8601 format time to filter notifications later than specified time
# @option options [String]   :earlier_than           (nil) ISO 8601 format time to filter notifications earlier than specified time
# @option options [Array]    :ids                    (nil) Array of specific notification IDs to destroy
# @return [Array<Notification>] Destroyed notification records
def destroy_all_of(target, options = {})
```

### 2. Target Model Method
**File**: `lib/activity_notification/models/concerns/target.rb`

Add instance method `destroy_all_notifications` following the pattern of `open_all_notifications`:

```ruby
# Destroys all notifications of the target matching the filter criteria.
#
# @param [Hash] options Options for filtering notifications to destroy
# @option options [String]   :filtered_by_type       (nil) Notifiable type for filter
# @option options [Object]   :filtered_by_group      (nil) Group instance for filter
# @option options [String]   :filtered_by_group_type (nil) Group type for filter, valid with :filtered_by_group_id
# @option options [String]   :filtered_by_group_id   (nil) Group instance id for filter, valid with :filtered_by_group_type
# @option options [String]   :filtered_by_key        (nil) Key of the notification for filter
# @option options [String]   :later_than             (nil) ISO 8601 format time to filter notifications later than specified time
# @option options [String]   :earlier_than           (nil) ISO 8601 format time to filter notifications earlier than specified time
# @option options [Array]    :ids                    (nil) Array of specific notification IDs to destroy
# @return [Array<Notification>] Destroyed notification records
def destroy_all_notifications(options = {})
```

### 3. Controller Actions

#### Web Controller
**File**: `app/controllers/activity_notification/notifications_controller.rb`

Add new action `destroy_all`:

```ruby
# Destroys all notifications of the target matching filter criteria.
#
# POST /:target_type/:target_id/notifications/destroy_all
# @overload destroy_all(params)
#   @param [Hash] params Request parameters
#   @option params [String] :filter                 (nil)     Filter option to load notification index by their status (Nothing as auto, 'opened' or 'unopened')
#   @option params [String] :limit                  (nil)     Maximum number of notifications to return
#   @option params [String] :without_grouping       ('false') Whether notification index will include group members
#   @option params [String] :with_group_members     ('false') Whether notification index will include group members
#   @option params [String] :filtered_by_type       (nil)     Notifiable type to filter notifications
#   @option params [String] :filtered_by_group_type (nil)     Group type to filter notifications, valid with :filtered_by_group_id
#   @option params [String] :filtered_by_group_id   (nil)     Group instance ID to filter notifications, valid with :filtered_by_group_type
#   @option params [String] :filtered_by_key        (nil)     Key of notifications to filter
#   @option params [String] :later_than             (nil)     ISO 8601 format time to filter notifications later than specified time
#   @option params [String] :earlier_than           (nil)     ISO 8601 format time to filter notifications earlier than specified time
#   @option params [Array]  :ids                    (nil)     Array of specific notification IDs to destroy
#   @option params [String] :reload                 ('true')  Whether notification index will be reloaded
#   @return [Response] JavaScript view for ajax request or redirects to back as default
def destroy_all
```

#### API Controller  
**File**: `app/controllers/activity_notification/notifications_api_controller.rb`

Add new action `destroy_all`:

```ruby
# Destroys all notifications of the target matching filter criteria.
#
# POST /:target_type/:target_id/notifications/destroy_all
# @overload destroy_all(params)
#   @param [Hash] params Request parameters
#   @option params [String] :filtered_by_type       (nil) Notifiable type to filter notifications
#   @option params [String] :filtered_by_group_type (nil) Group type to filter notifications, valid with :filtered_by_group_id
#   @option params [String] :filtered_by_group_id   (nil) Group instance ID to filter notifications, valid with :filtered_by_group_type
#   @option params [String] :filtered_by_key        (nil) Key of notifications to filter
#   @option params [String] :later_than             (nil) ISO 8601 format time to filter notifications later than specified time
#   @option params [String] :earlier_than           (nil) ISO 8601 format time to filter notifications earlier than specified time
#   @option params [Array]  :ids                    (nil) Array of specific notification IDs to destroy
#   @return [JSON] count: number of destroyed notification records, notifications: destroyed notifications
def destroy_all
```

### 4. Routes Configuration
**File**: Routes will be automatically generated by the existing `notify_to` helper

The route will be: `POST /:target_type/:target_id/notifications/destroy_all`

### 5. View Templates
**Files**: 
- `app/views/activity_notification/notifications/default/destroy_all.js.erb`
- Template generators will need to be updated to include the new view

### 6. Swagger API Documentation
**File**: Update Swagger documentation to include the new bulk destroy endpoint

### 7. Generator Templates
**Files**: Update controller generator templates to include the new `destroy_all` action:
- `lib/generators/templates/controllers/notifications_api_controller.rb`
- `lib/generators/templates/controllers/notifications_controller.rb`
- `lib/generators/templates/controllers/notifications_with_devise_controller.rb`

## Implementation Details

### Filter Options Support
The bulk destroy API will support the same filtering options as the existing `open_all` functionality:
- `filtered_by_type`: Filter by notifiable type
- `filtered_by_group_type` + `filtered_by_group_id`: Filter by group
- `filtered_by_key`: Filter by notification key
- `later_than` / `earlier_than`: Filter by time range
- `ids`: Array of specific notification IDs (new option for precise control)

### Safety Considerations
1. **Validation**: Ensure all notifications belong to the specified target
2. **Permissions**: Leverage existing authentication/authorization patterns
3. **Soft Delete**: Consider if soft delete should be supported (follow existing destroy pattern)
4. **Callbacks**: Ensure any existing destroy callbacks are properly triggered

### Performance Considerations
1. **Batch Operations**: Use `destroy_all` for efficient database operations
2. **Memory Usage**: For large datasets, consider pagination or streaming
3. **Callbacks**: Balance between performance and callback execution

### Error Handling
1. **Partial Failures**: Handle cases where some notifications can't be destroyed
2. **Validation Errors**: Provide meaningful error messages
3. **Authorization Errors**: Consistent with existing error handling patterns

## Testing Requirements

### Unit Tests
- Test `NotificationApi#destroy_all_of` method
- Test `Target#destroy_all_notifications` method
- Test controller actions for both web and API versions

### Integration Tests
- Test complete request/response cycle
- Test with various filter combinations
- Test error scenarios

### Performance Tests
- Test with large datasets
- Verify efficient database queries

## Migration Considerations
- No database schema changes required
- Backward compatible addition
- Follows existing patterns and conventions

## Documentation Updates
- Update README.md with new bulk destroy functionality
- Update API documentation
- Update controller documentation
- Add examples to documentation

## Alternative Implementation Options

### Option 1: Single Endpoint with Multiple IDs
Instead of filter-based bulk destroy, accept an array of notification IDs:
```
POST /:target_type/:target_id/notifications/destroy_all
Body: { "ids": [1, 2, 3, 4, 5] }
```

### Option 2: RESTful Bulk Operations
Follow RESTful conventions with a bulk operations endpoint:
```
POST /:target_type/:target_id/notifications/bulk
Body: { "action": "destroy", "filters": {...} }
```

### Option 3: Query Parameter Approach
Use existing destroy endpoint with query parameters:
```
DELETE /:target_type/:target_id/notifications?ids[]=1&ids[]=2&ids[]=3
```

## Recommended Approach
The proposed implementation follows the existing pattern established by `open_all` functionality, making it consistent with the current codebase architecture. This approach provides:

1. **Consistency**: Matches existing bulk operation patterns
2. **Flexibility**: Supports various filtering options
3. **Safety**: Leverages existing validation and authorization
4. **Performance**: Uses efficient bulk database operations
5. **Maintainability**: Follows established code organization

The implementation should prioritize the filter-based approach (similar to `open_all`) while also supporting the `ids` parameter for precise control when needed.