# Performance Tests for NotificationApi Batch Processing Optimization

## Overview

This document describes the performance tests created to validate and measure the optimization improvements implemented in response to PR comment 3701283908 from simukappu.

## Optimization Summary

The performance optimization addresses memory efficiency issues when handling large target collections:

### Key Optimizations

1. **`targets_empty?` optimization** (line 232 in notification_api.rb)
   - **Before**: Used `targets.blank?` which loads all records into memory
   - **After**: Uses `targets.exists?` for ActiveRecord/Mongoid (SQL: `SELECT 1 LIMIT 1`)
   - **Benefit**: Avoids loading thousands of records just to check if collection is empty

2. **`process_targets_in_batches` optimization** (line 303 in notification_api.rb)
   - **Before**: Used `targets.map` which loads all records into memory at once
   - **After**: 
     - ActiveRecord relations: Uses `find_each` (default batch size: 1000)
     - Mongoid criteria: Uses `each` with cursor batching
     - Arrays: Falls back to standard `map` (already in memory)
   - **Benefit**: Processes large collections in batches to minimize memory footprint

### Expected Performance Improvements

Based on the commit message, the optimization provides:

- **10K records**: 90% memory reduction (100MB → 10MB)
- **100K records**: 99% memory reduction (1GB → 10MB)
- **1M records**: 99.9% memory reduction (10GB → 10MB)

## Test File Location

```
spec/concerns/apis/notification_api_performance_spec.rb
```

## Running the Tests

### Run all performance tests

```bash
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb
```

### Run with detailed output

```bash
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb --format documentation
```

### Run specific test contexts

```bash
# Test only the targets_empty? optimization
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "targets_empty? optimization"

# Test only batch processing optimization
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "batch processing optimization"

# Test memory efficiency comparison
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "comparing optimized vs unoptimized"
```

### Run as part of full test suite

The performance tests are integrated into the main test suite via `notification_spec.rb`, so they run automatically with:

```bash
bundle exec rspec
# or
bundle exec rake
```

## Test Coverage

### 1. Empty Check Optimization Tests

- **Validates `exists?` is used instead of `blank?`**: Ensures the optimized path is taken for ActiveRecord relations
- **Measures query efficiency**: Confirms at most 1 SELECT query is executed for empty check
- **Tests empty collection handling**: Verifies correct behavior with empty target collections

### 2. Batch Processing Tests

#### Small Collections (< 1000 records)
- Tests with 50 records
- Validates `find_each` is called for ActiveRecord relations
- Ensures records are not loaded all at once via `to_a` or `load`
- Confirms all notifications are created successfully

#### Medium Collections (1000+ records)
- Tests with 1000 records
- Validates batch processing with default batch size
- Tests custom `batch_size` option
- **Memory efficiency test**: Measures memory consumption during processing
- **Query efficiency test**: Tracks SELECT queries to validate batching

#### Array Inputs
- Tests fallback behavior for arrays (already in memory)
- Validates `map` is used appropriately for arrays

### 3. Performance Comparison Tests

- **Memory usage comparison**: Compares loading all records vs batch processing
- **Performance metrics**: Measures processing time, throughput, and average time per notification
- **Provides quantifiable evidence** with detailed output:
  ```
  === Memory Usage Comparison (500 records) ===
  Loading all records: 12.34MB
  Batch processing: 8.76MB
  Difference: 3.58MB
  
  === Performance Metrics (500 records) ===
  Total notifications created: 500
  Processing time: 1234.56ms
  Average time per notification: 2.469ms
  Throughput: 405.12 notifications/second
  ```

### 4. Integration Tests

- Tests `notify` method with large target collections (200 records)
- Validates complete workflow from empty check through batch processing
- Confirms all notifications are created correctly

### 5. Regression Tests

- Ensures backward compatibility with existing functionality
- Tests both `notify_all` with arrays and relations
- Validates notification content is correct

## Performance Test Design Principles

### Memory Efficiency Testing

The tests measure memory consumption using system-level RSS (Resident Set Size):

```ruby
memory_before = `ps -o rss= -p #{Process.pid}`.to_i
# ... perform operation ...
memory_after = `ps -o rss= -p #{Process.pid}`.to_i
memory_increase_mb = (memory_after - memory_before) / 1024.0
```

### Query Efficiency Testing

The tests track SQL queries using ActiveSupport::Notifications:

```ruby
ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  # Count and analyze queries
end
```

### Behavioral Verification

The tests use RSpec mocking to verify specific methods are called:

```ruby
expect(relation).to receive(:find_each).and_call_original
expect(relation).not_to receive(:to_a)
```

## Interpreting Test Results

### Success Indicators

1. **Memory tests pass**: Memory consumption stays below thresholds
2. **Query efficiency verified**: Batch processing uses minimal queries
3. **Method calls validated**: Correct optimization paths are taken
4. **Metrics show improvement**: Performance numbers demonstrate efficiency gains

### What to Look For

- **Memory increase < 50MB for 1000 records**: Indicates effective batch processing
- **Query count < 100 for large collections**: Shows queries are batched, not N+1
- **`find_each` is called**: Confirms ActiveRecord batch processing is active
- **`exists?` is used for empty check**: Validates optimization is applied

### Performance Metrics Output

When tests run, you'll see detailed performance metrics in the console:

```
=== Memory Usage Comparison (500 records) ===
Loading all records: XX.XXmb
Batch processing: XX.XXmb
Difference: XX.XXmb

=== Performance Metrics (500 records) ===
Total notifications created: 500
Processing time: XXXXms
Average time per notification: X.XXXms
Throughput: XXX.XX notifications/second
```

These metrics provide quantifiable evidence that the optimization is working.

## Test Data Management

### Setup
- Tests create users dynamically using FactoryBot
- Large collections are created in batches to avoid memory issues during setup

### Cleanup
- Tests clean up created records in `after` blocks
- Uses `delete_all` for efficient cleanup
- Cleans both User records and Notification records

## Troubleshooting

### Tests are slow
- This is expected for tests with 1000+ records
- Performance tests intentionally use larger datasets to demonstrate improvements
- Consider using `--tag ~slow` to skip performance tests in rapid development cycles

### Memory tests fail
- Check if other processes are consuming memory
- Ensure adequate system memory is available
- GC timing can affect results; tests include `GC.start` to minimize variance

### Query count varies
- Query counts can vary slightly based on database adapter and Rails version
- Tests use reasonable thresholds rather than exact counts
- Check if eager loading or includes are adding queries

## Future Enhancements

Potential improvements to the test suite:

1. **Benchmark against different ORMs**: Add Mongoid and Dynamoid specific tests
2. **Test with Rails version matrix**: Validate across Rails 5.0-8.0
3. **Database adapter comparison**: Test PostgreSQL vs MySQL vs SQLite behavior
4. **Profiling integration**: Add memory_profiler or benchmark-ips gems
5. **CI integration**: Add performance regression checks in CI pipeline

## Related Documentation

- Main test suite: `spec/concerns/apis/notification_api_spec.rb`
- Model tests: `spec/models/notification_spec.rb`
- Testing guide: `docs/Testing.md`
- Implementation: `lib/activity_notification/apis/notification_api.rb`

## Credits

These tests address the performance validation request from simukappu in PR comment 3701283908, providing quantifiable evidence that the batch processing optimization delivers the promised memory efficiency improvements.
