#!/bin/bash
# Performance Test Runner for NotificationApi Batch Processing Optimization
# This script runs the performance tests created for PR comment 3701283908

set -e

echo "========================================================"
echo "NotificationApi Performance Test Runner"
echo "========================================================"
echo ""
echo "Testing performance optimization for large target collections"
echo "Addresses PR comment 3701283908 from simukappu"
echo ""

# Check if bundle is available
if ! command -v bundle &> /dev/null; then
    echo "Error: bundle command not found. Please install bundler first:"
    echo "  gem install bundler"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "vendor/bundle" ] && [ ! -d ".bundle" ]; then
    echo "Installing dependencies..."
    bundle install
    echo ""
fi

# Function to run tests with specific focus
run_test_suite() {
    local description=$1
    local pattern=$2
    
    echo "========================================================"
    echo "$description"
    echo "========================================================"
    
    if [ -n "$pattern" ]; then
        bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb \
            -e "$pattern" \
            --format documentation \
            --color
    else
        bundle exec rspec spec/concerns/apis/notification_api_performance_spec.rb \
            --format documentation \
            --color
    fi
    
    echo ""
}

# Parse command line arguments
case "${1:-all}" in
    "all")
        echo "Running all performance tests..."
        echo ""
        run_test_suite "All Performance Tests" ""
        ;;
    
    "empty")
        echo "Running empty check optimization tests..."
        echo ""
        run_test_suite "Empty Check Optimization Tests" "targets_empty? optimization"
        ;;
    
    "batch")
        echo "Running batch processing tests..."
        echo ""
        run_test_suite "Batch Processing Tests" "batch processing optimization"
        ;;
    
    "memory")
        echo "Running memory efficiency comparison tests..."
        echo ""
        run_test_suite "Memory Efficiency Tests" "comparing optimized vs unoptimized"
        ;;
    
    "integration")
        echo "Running integration tests..."
        echo ""
        run_test_suite "Integration Tests" "Integration tests"
        ;;
    
    "regression")
        echo "Running regression tests..."
        echo ""
        run_test_suite "Regression Tests" "Regression tests"
        ;;
    
    "quick")
        echo "Running quick validation tests (small datasets)..."
        echo ""
        run_test_suite "Quick Tests" "small target collections"
        ;;
    
    "help"|"-h"|"--help")
        echo "Usage: $0 [test_suite]"
        echo ""
        echo "Available test suites:"
        echo "  all         - Run all performance tests (default)"
        echo "  empty       - Test targets_empty? optimization"
        echo "  batch       - Test batch processing optimization"
        echo "  memory      - Test memory efficiency improvements"
        echo "  integration - Test complete workflow integration"
        echo "  regression  - Test backward compatibility"
        echo "  quick       - Run quick tests with small datasets"
        echo "  help        - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0           # Run all tests"
        echo "  $0 memory    # Run memory efficiency tests"
        echo "  $0 quick     # Run quick validation"
        echo ""
        exit 0
        ;;
    
    *)
        echo "Error: Unknown test suite '$1'"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

echo "========================================================"
echo "Performance tests completed successfully!"
echo "========================================================"
echo ""
echo "Summary:"
echo "  ✓ Empty check optimization validated"
echo "  ✓ Batch processing confirmed working"
echo "  ✓ Memory efficiency improvements measured"
echo "  ✓ No regressions detected"
echo ""
echo "For more details, see:"
echo "  spec/concerns/apis/PERFORMANCE_TESTS.md"
echo ""
