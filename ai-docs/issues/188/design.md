# Design Document

## Overview

This design outlines the approach for upgrading activity_notification's Dynamoid dependency from v3.1.0 to v3.11.0. The upgrade involves updating namespace references, method signatures, and class hierarchies that have changed between these versions, while maintaining backward compatibility and preparing useful enhancements for upstream contribution to Dynamoid.

## Architecture

### Current Architecture
- **Dynamoid Extension**: `lib/activity_notification/orm/dynamoid/extension.rb` contains monkey patches extending Dynamoid v3.1.0
- **ORM Integration**: `lib/activity_notification/orm/dynamoid.rb` provides ActivityNotification-specific query methods
- **Dependency Management**: Gemspec pins Dynamoid to exactly v3.1.0

### Target Architecture
- **Updated Extension**: Refactored extension file compatible with Dynamoid v3.11.0 namespaces
- **Backward Compatibility**: Maintained API surface for existing applications
- **Upstream Preparation**: Clean, well-documented code ready for Dynamoid contribution
- **Flexible Dependency**: Version range allowing v3.11.0+ while preventing breaking v4.0 changes

## Components and Interfaces

### 1. Gemspec Update
**File**: `activity_notification.gemspec`
**Changes**:
- Update Dynamoid dependency from development dependency `'3.1.0'` to runtime dependency `'>= 3.11.0', '< 4.0'`
- Change dependency type from `add_development_dependency` to `add_dependency` for production use
- Ensure compatibility with Rails version constraints

### 2. Extension Module Refactoring
**File**: `lib/activity_notification/orm/dynamoid/extension.rb`

#### 2.1 Critical Namespace Changes
Based on analysis of Dynamoid v3.1.0 vs v3.11.0:

**Query and Scan Class Locations**:
- **v3.1.0**: `Dynamoid::AdapterPlugin::Query` and `Dynamoid::AdapterPlugin::Scan`
- **v3.11.0**: `Dynamoid::AdapterPlugin::AwsSdkV3::Query` and `Dynamoid::AdapterPlugin::AwsSdkV3::Scan`

**Method Signature Changes**:
- **v3.1.0**: `Query.new(client, table, opts = {})`
- **v3.11.0**: `Query.new(client, table, key_conditions, non_key_conditions, options)`

#### 2.2 Removed Constants and Methods
**Constants removed in v3.11.0**:
- `FIELD_MAP` - Used for condition mapping
- `RANGE_MAP` - Used for range condition mapping
- `attribute_value_list()` method - No longer exists

**New Architecture in v3.11.0**:
- Uses `FilterExpressionConvertor` for building filter expressions
- Uses expression attribute names and values instead of legacy condition format
- Middleware pattern for handling backoff, limits, and pagination

#### 2.3 Class Hierarchy Updates Required
- Update inheritance from `::Dynamoid::AdapterPlugin::Query` to `::Dynamoid::AdapterPlugin::AwsSdkV3::Query`
- Update inheritance from `::Dynamoid::AdapterPlugin::Scan` to `::Dynamoid::AdapterPlugin::AwsSdkV3::Scan`
- Remove references to `FIELD_MAP`, `RANGE_MAP`, and `attribute_value_list()`
- Adapt to new filter expression format

### 3. Core Functionality Preservation
**Methods to Maintain**:
- `none()` - Returns empty result set
- `limit()` - Aliases to `record_limit()`
- `exists?()` - Checks if records exist
- `update_all()` - Batch update operations
- `serializable_hash()` - Array serialization
- Null/not_null operators for query filtering
- Uniqueness validation support

### 4. Upstream Contribution Preparation
**Target Methods for Contribution**:
- `Chain#none` - Useful empty result pattern
- `Chain#limit` - More intuitive alias for `record_limit`
- `Chain#exists?` - Common query pattern
- `Chain#update_all` - Batch operations
- Null operator extensions - Enhanced query capabilities
- Uniqueness validator - Common validation need

## Data Models

### Extension Points
```ruby
# Current structure (v3.1.0)
module Dynamoid
  module Criteria
    class Chain
      # Extension methods work with @query hash
    end
  end
  
  module AdapterPlugin
    class AwsSdkV3
      class Query < ::Dynamoid::AdapterPlugin::Query
        # Uses FIELD_MAP, RANGE_MAP, attribute_value_list
        def query_filter
          # Legacy condition format
        end
      end
    end
  end
end

# Target structure (v3.11.0) - CONFIRMED
module Dynamoid
  module Criteria
    class Chain
      # Extension methods work with @where_conditions object
      # Uses KeyFieldsDetector and WhereConditions classes
    end
  end
  
  module AdapterPlugin
    class AwsSdkV3
      class Query < ::Dynamoid::AdapterPlugin::AwsSdkV3::Query  # CHANGED NAMESPACE
        # Uses FilterExpressionConvertor instead of FIELD_MAP
        # No more query_filter method - uses filter_expression
        def initialize(client, table, key_conditions, non_key_conditions, options)
          # CHANGED SIGNATURE
        end
      end
    end
  end
end
```

### Critical Breaking Changes
1. **Query/Scan inheritance path changed**: `::Dynamoid::AdapterPlugin::Query` → `::Dynamoid::AdapterPlugin::AwsSdkV3::Query`
2. **Constructor signature changed**: Single options hash → separate key/non-key conditions + options
3. **Filter building changed**: `FIELD_MAP`/`RANGE_MAP` → `FilterExpressionConvertor`
4. **Method removal**: `attribute_value_list()`, `query_filter()`, `scan_filter()` methods removed

### Configuration Changes
- No breaking changes to ActivityNotification configuration
- Maintain existing API for `acts_as_notification_target`, `acts_as_notifiable`, etc.
- Preserve all existing query method signatures

## Error Handling

### Migration Strategy
1. **Gradual Rollout**: Support version range to allow gradual adoption
2. **Fallback Mechanisms**: Detect Dynamoid version and use appropriate code paths if needed
3. **Clear Error Messages**: Provide helpful errors if incompatible versions are used

### Exception Handling
- **NameError**: Handle missing classes/modules gracefully
- **NoMethodError**: Provide fallbacks for changed method signatures
- **ArgumentError**: Handle parameter changes in Dynamoid methods

### Validation
- Runtime checks for critical Dynamoid functionality
- Test coverage for all supported Dynamoid versions
- Integration tests with real DynamoDB operations

## Testing Strategy

### Unit Tests
- Test all extension methods with Dynamoid v3.11.0
- Verify namespace resolution works correctly
- Test error handling for edge cases

### Integration Tests
- Full ActivityNotification workflow with DynamoDB
- Performance regression testing
- Memory usage validation

### Compatibility Tests
- Test with multiple Dynamoid versions in range
- Verify no breaking changes for existing applications
- Test upgrade path from v3.1.0 to v3.11.0

### Upstream Preparation Tests
- Isolated tests for each method proposed for contribution
- Documentation examples that work standalone
- Performance benchmarks for contributed methods

## Implementation Phases

### Phase 1: Research and Analysis ✅ COMPLETED
- ✅ Compare Dynamoid v3.1.0 vs v3.11.0 source code
- ✅ Identify all namespace and method signature changes
- ✅ Create compatibility matrix

**Key Findings**:
- Query/Scan classes moved from `AdapterPlugin::` to `AdapterPlugin::AwsSdkV3::`
- Constructor signatures completely changed
- FIELD_MAP/RANGE_MAP constants removed
- Filter building now uses FilterExpressionConvertor
- Legacy query_filter/scan_filter methods removed

### Phase 2: Core Updates
- Update gemspec dependency
- Refactor extension.rb for new namespaces
- Maintain existing functionality

### Phase 3: Testing and Validation
- Update test suite for new Dynamoid version
- Run comprehensive integration tests using `AN_ORM=dynamoid bundle exec rspec`
- Fix failing tests to ensure all Dynamoid-related functionality works
- Performance validation
- Verify all existing test scenarios pass with new Dynamoid version

### Phase 4: Upstream Preparation
- Extract reusable methods into separate modules
- Create documentation and examples
- Prepare pull requests for Dynamoid project

### Phase 5: Documentation and Release
- Update CHANGELOG with breaking changes
- Update README with version requirements
- Release new version with proper semantic versioning

## Risk Mitigation

### Breaking Changes
- Use version range to prevent automatic v4.0 adoption
- Provide clear upgrade documentation
- Maintain backward compatibility where possible

### Performance Impact
- Benchmark critical query operations
- Monitor memory usage changes
- Test with large datasets

### Upstream Contribution Risks
- Prepare contributions as optional enhancements
- Ensure activity_notification works without upstream acceptance
- Maintain local implementations as fallbacks