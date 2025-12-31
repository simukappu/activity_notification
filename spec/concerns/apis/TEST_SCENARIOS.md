# Performance Test Scenarios

This document outlines the specific test scenarios implemented to validate the batch processing optimization for NotificationApi (PR comment 3701283908).

## Test Scenario Matrix

### 1. Empty Check Optimization Tests

| Scenario | Input | Expected Behavior | Validation Method |
|----------|-------|-------------------|-------------------|
| ActiveRecord relation empty check | `User.none` | Calls `exists?`, not `blank?` | Mock verification |
| Query efficiency | Empty relation | ≤1 SELECT query | Query counting |
| Empty collection handling | Empty targets | Returns nil | Result checking |

**What's Being Tested**: The optimization that uses `exists?` for ActiveRecord relations instead of `blank?`, which avoids loading all records just to check if collection is empty.

**Key Assertion**: `expect(relation).to receive(:exists?)` and `expect(relation).not_to receive(:blank?)`

---

### 2. Batch Processing Tests - Small Collections (50 records)

| Scenario | Input | Expected Behavior | Validation Method |
|----------|-------|-------------------|-------------------|
| ActiveRecord relation processing | 50 user records | Uses `find_each` | Mock verification |
| Memory efficiency | 50 user relation | Doesn't load all records | Negative assertion on `to_a` |
| Notification creation | 50 targets | All notifications created | Count assertion |

**What's Being Tested**: That even with smaller collections, the batch processing approach is used correctly.

**Key Assertions**:
- `expect(relation).to receive(:find_each)`
- `expect(relation).not_to receive(:to_a)`
- `expect(notifications.size).to eq(50)`

---

### 3. Batch Processing Tests - Medium Collections (1000 records)

| Scenario | Input | Expected Behavior | Validation Method |
|----------|-------|-------------------|-------------------|
| Large relation processing | 1000 user records | Processes in batches | Callback counting |
| Custom batch_size | 1000 records, batch_size: 250 | Uses custom size | Mock verification |
| Memory efficiency | 1000 records | Memory increase <50MB | System memory monitoring |
| Query optimization | 1000 records | Query count <100 | Query tracking |
| Performance metrics | 1000 records | Outputs timing/throughput | Console output |

**What's Being Tested**: The real-world performance benefits with larger collections.

**Key Assertions**:
- `expect(relation).to receive(:find_each).with(hash_including(batch_size: 250))`
- `expect(memory_increase_mb).to be < 50`
- `expect(select_query_count).to be < 100`

---

### 4. Array Fallback Tests

| Scenario | Input | Expected Behavior | Validation Method |
|----------|-------|-------------------|-------------------|
| Array processing | Array of 10 users | Uses `map` | Mock verification |
| Notification creation | Array input | All notifications created | Count assertion |

**What's Being Tested**: That arrays (already in memory) use the appropriate processing method.

**Key Assertion**: `expect(@users).to receive(:map)`

---

### 5. Performance Comparison Tests (500 records)

| Scenario | Old Approach | New Approach | Validation Method |
|----------|--------------|--------------|-------------------|
| Memory usage | Load all with `to_a` | Batch with `find_each` | RSS comparison |
| Processing time | Time to process 500 | Time with batching | Duration measurement |
| Throughput | Records/second old | Records/second new | Rate calculation |

**What's Being Tested**: Direct comparison showing quantifiable improvements.

**Metrics Output**:
```
=== Memory Usage Comparison (500 records) ===
Loading all records: XX.XXmb
Batch processing: XX.XXmb
Difference: XX.XXmb

=== Performance Metrics (500 records) ===
Total notifications created: 500
Processing time: XXXXms
Average time per notification: X.XXms
Throughput: XXX.XX notifications/second
```

**Key Assertion**: `expect(memory_new_mb).to be < (memory_old_mb * 1.5)`

---

### 6. Integration Tests (200 records)

| Scenario | Input | Expected Behavior | Validation Method |
|----------|-------|-------------------|-------------------|
| Complete notify workflow | 200 user relation | Empty check + batch process | End-to-end test |
| Notification creation | 200 targets | All created correctly | Database verification |
| Empty vs non-empty | Toggle targets | Correct handling | Conditional assertion |

**What's Being Tested**: The complete workflow from `notify` through `notify_all` to `process_targets_in_batches`.

**Key Assertions**:
- `expect(notifications.size).to eq(200)`
- `expect(user.notifications.where(notifiable: @comment).count).to eq(1)`

---

### 7. Regression Tests

| Scenario | Input | Expected Behavior | Validation Method |
|----------|-------|-------------------|-------------------|
| Backward compatibility | Standard usage | Same as before | Result comparison |
| Array notify_all | Array of users | Works correctly | Count assertion |
| Relation notify_all | ActiveRecord relation | Works correctly | Count + DB check |
| Notification content | Various inputs | Correct attributes | Content validation |

**What's Being Tested**: That the optimization doesn't break existing functionality.

**Key Assertions**:
- `expect(notifications).to be_a(Array)`
- `expect(notification.notifiable).to eq(@comment)`
- `expect([User]).to include(notification.target.class)`

---

## Test Data Sizes and Rationale

| Test Type | Record Count | Rationale |
|-----------|--------------|-----------|
| Small collection | 50 | Fast execution, validates basic batch processing |
| Medium collection | 1000 | Demonstrates memory benefits, manageable test time |
| Integration | 200 | Balance between thoroughness and speed |
| Comparison | 500 | Large enough to show differences, fast enough for CI |

---

## Memory Efficiency Validation

### Measurement Approach
```ruby
memory_before = `ps -o rss= -p #{Process.pid}`.to_i
# ... perform operation ...
memory_after = `ps -o rss= -p #{Process.pid}`.to_i
memory_increase_mb = (memory_after - memory_before) / 1024.0
```

### Expected Thresholds
- **1000 records**: Memory increase <50MB
- **500 records**: Batch processing ≤ 1.5x loading all records
- **Large collections**: Linear scaling prevented by batching

---

## Query Efficiency Validation

### Measurement Approach
```ruby
ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  query_count += 1 if event.payload[:sql] =~ /SELECT.*FROM.*users/i
end
```

### Expected Thresholds
- **Empty check**: ≤1 query (SELECT 1 LIMIT 1)
- **1000 records batch**: <100 queries (not N+1)
- **General**: Queries should not scale linearly with record count

---

## Behavioral Verification

### Method Call Verification
Tests verify correct methods are called using RSpec mocks:

**Should Be Called**:
- `exists?` for empty checks
- `find_each` for ActiveRecord relations
- `each` for Mongoid criteria (when available)

**Should NOT Be Called**:
- `blank?` on relations (loads all records)
- `to_a` on relations (loads all records)
- `load` on relations (loads all records)

---

## Performance Metrics Collected

For quantifiable evidence, tests collect and output:

1. **Memory Metrics**
   - Memory before operation (RSS)
   - Memory after operation (RSS)
   - Memory increase (MB)
   - Comparison between approaches

2. **Timing Metrics**
   - Processing start time
   - Processing end time
   - Total duration (ms)
   - Average time per notification (ms)

3. **Throughput Metrics**
   - Total notifications created
   - Notifications per second
   - Records processed per second

4. **Query Metrics**
   - SELECT query count
   - Query patterns (batched vs N+1)

---

## Success Criteria Summary

Tests pass when:

✓ **Empty Check**: `exists?` is used, ≤1 query executed  
✓ **Batch Processing**: `find_each` is used for relations  
✓ **Memory Efficiency**: Memory stays within defined thresholds  
✓ **Query Optimization**: Queries are batched, not N+1  
✓ **Custom Options**: `batch_size` option is respected  
✓ **Correctness**: All notifications are created properly  
✓ **Regression**: No breaking changes to existing functionality  
✓ **Metrics**: Performance metrics show expected improvements  

---

## Running Specific Scenarios

```bash
# Empty check tests
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "empty check"

# Small collection tests
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "small target collections"

# Medium collection tests
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "medium target collections"

# Memory comparison
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "comparing optimized vs unoptimized"

# Integration tests
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "Integration tests"

# Regression tests
bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb -e "Regression tests"
```

---

## Expected Performance Improvements

Based on the optimization commit, tests validate:

| Record Count | Memory Reduction | Old Memory | New Memory |
|--------------|------------------|------------|------------|
| 10,000       | 90%              | 100MB      | 10MB       |
| 100,000      | 99%              | 1GB        | 10MB       |
| 1,000,000    | 99.9%            | 10GB       | 10MB       |

These improvements are achieved through:
1. Using `exists?` instead of loading all records for empty checks
2. Using `find_each` to process records in batches (default 1000)
3. Configurable batch_size for fine-tuning
4. Cursor-based iteration for Mongoid

---

## Test Isolation and Cleanup

All tests include proper setup and teardown:

```ruby
before do
  # Create test data
  @users = create_list(:confirmed_user, count)
end

after do
  # Clean up test data
  User.where(id: @users.map(&:id)).delete_all
  described_class.where(notifiable: @comment).delete_all
end
```

This ensures:
- Tests don't interfere with each other
- Database doesn't accumulate test data
- Memory is freed between tests
- Tests can run in any order

---

## Troubleshooting Test Scenarios

### If memory tests fail:
- Check if other processes are consuming memory
- Verify adequate system memory available
- GC timing can affect results (tests include `GC.start`)
- RSS measurement can vary ±10-20% normally

### If query tests fail:
- Check ActiveRecord logging configuration
- Query counts may vary by Rails version
- Eager loading can add queries
- Background jobs may run during tests

### If timing tests fail:
- System load affects performance
- CI environments may be slower
- Tests use generous thresholds to account for variance
- Focus on relative improvements, not absolute numbers

---

## Related Files

- **Test Implementation**: `notification_api_performance_spec.rb`
- **Main Documentation**: `PERFORMANCE_TESTS.md`
- **Quick Reference**: `README_PERFORMANCE.md`
- **Test Runner**: `run_performance_tests.sh`
- **Code Being Tested**: `lib/activity_notification/apis/notification_api.rb`

---

*This test scenario documentation ensures clear understanding of what each test validates and how to interpret results.*
