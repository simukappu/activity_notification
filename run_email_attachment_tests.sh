#!/bin/bash

# Email Attachments Test Suite - Quick Test Runner
# This script helps run all the email attachments tests

set -e

echo "=================================="
echo "Email Attachments Test Suite"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run tests with a header
run_test() {
  local test_file=$1
  local description=$2
  
  echo -e "${BLUE}Running: $description${NC}"
  echo "File: $test_file"
  echo "----------------------------------"
  
  bundle exec rspec "$test_file" --format documentation
  
  echo ""
}

# Check if bundle is available
if ! command -v bundle &> /dev/null; then
    echo "Error: bundle command not found. Please install bundler first."
    exit 1
fi

# Navigate to project root
cd "$(dirname "$0")/.." || exit 1

echo "Project: activity_notification"
echo "Test Suite: Email Attachments Feature"
echo ""
echo "This test suite covers:"
echo "  - CustomNotificationMailer with attachments"
echo "  - Invoice model with PDF generation"
echo "  - MonthlyReportGenerator service"
echo "  - Email template views"
echo "  - Factory definitions"
echo "  - Integration workflows"
echo "  - Helper methods"
echo "  - Advanced scenarios"
echo ""
echo "Total Tests: 260+"
echo "Total Lines: ~3,000"
echo "Coverage Goal: ≥99.749%"
echo ""
echo "=================================="
echo ""

# Parse command line arguments
if [ "$1" = "all" ] || [ -z "$1" ]; then
  echo "Running ALL email attachments tests..."
  echo ""
  
  run_test "spec/mailers/custom_notification_mailer_spec.rb" "Mailer Tests (40+ tests)"
  run_test "spec/models/invoice_spec.rb" "Invoice Model Tests (35+ tests)"
  run_test "spec/services/monthly_report_generator_spec.rb" "Monthly Report Service Tests (35+ tests)"
  run_test "spec/integration/email_attachments_integration_spec.rb" "Integration Tests (25+ tests)"
  run_test "spec/views/email_templates_spec.rb" "Email Template Tests (30+ tests)"
  run_test "spec/factories/invoices_spec.rb" "Factory Tests (35+ tests)"
  run_test "spec/helpers/email_attachments_helper_spec.rb" "Helper Tests (30+ tests)"
  run_test "spec/advanced/email_attachments_advanced_spec.rb" "Advanced Scenario Tests (30+ tests)"
  
  echo -e "${GREEN}=================================="
  echo "All tests completed!"
  echo "==================================${NC}"
  
elif [ "$1" = "mailer" ]; then
  run_test "spec/mailers/custom_notification_mailer_spec.rb" "Mailer Tests"
  
elif [ "$1" = "model" ]; then
  run_test "spec/models/invoice_spec.rb" "Invoice Model Tests"
  
elif [ "$1" = "service" ]; then
  run_test "spec/services/monthly_report_generator_spec.rb" "Monthly Report Service Tests"
  
elif [ "$1" = "integration" ]; then
  run_test "spec/integration/email_attachments_integration_spec.rb" "Integration Tests"
  
elif [ "$1" = "views" ]; then
  run_test "spec/views/email_templates_spec.rb" "Email Template Tests"
  
elif [ "$1" = "factory" ]; then
  run_test "spec/factories/invoices_spec.rb" "Factory Tests"
  
elif [ "$1" = "helpers" ]; then
  run_test "spec/helpers/email_attachments_helper_spec.rb" "Helper Tests"
  
elif [ "$1" = "advanced" ]; then
  run_test "spec/advanced/email_attachments_advanced_spec.rb" "Advanced Scenario Tests"
  
elif [ "$1" = "coverage" ]; then
  echo "Running tests with coverage report..."
  echo ""
  COVERAGE=true bundle exec rspec spec/mailers/custom_notification_mailer_spec.rb \
                                  spec/models/invoice_spec.rb \
                                  spec/services/monthly_report_generator_spec.rb \
                                  spec/integration/email_attachments_integration_spec.rb \
                                  spec/views/email_templates_spec.rb \
                                  spec/factories/invoices_spec.rb \
                                  spec/helpers/email_attachments_helper_spec.rb \
                                  spec/advanced/email_attachments_advanced_spec.rb
  
  echo ""
  echo -e "${GREEN}Coverage report generated!${NC}"
  echo "Check coverage/index.html for detailed coverage report"
  
elif [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 [option]"
  echo ""
  echo "Options:"
  echo "  all         Run all email attachments tests (default)"
  echo "  mailer      Run CustomNotificationMailer tests only"
  echo "  model       Run Invoice model tests only"
  echo "  service     Run MonthlyReportGenerator service tests only"
  echo "  integration Run integration tests only"
  echo "  views       Run email template view tests only"
  echo "  factory     Run factory tests only"
  echo "  helpers     Run helper method tests only"
  echo "  advanced    Run advanced scenario tests only"
  echo "  coverage    Run all tests with coverage report"
  echo "  help        Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0              # Run all tests"
  echo "  $0 all          # Run all tests"
  echo "  $0 mailer       # Run mailer tests only"
  echo "  $0 coverage     # Run all tests with coverage"
  echo ""
  
else
  echo "Unknown option: $1"
  echo "Run '$0 help' for usage information"
  exit 1
fi
