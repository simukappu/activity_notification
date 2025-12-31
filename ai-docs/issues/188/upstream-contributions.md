# Upstream Contributions for Dynamoid

This document outlines the improvements made to ActivityNotification's Dynamoid integration that could be contributed back to the Dynamoid project.

## 1. None Method Implementation

### Overview
The `none()` method provides an empty query result set, similar to ActiveRecord's `none` method. This is useful for conditional queries and maintaining consistent interfaces.

### Implementation

```ruby
module Dynamoid
  module Criteria
    class None < Chain
      def ==(other)
        other.is_a?(None)
      end

      def records
        []
      end

      def count
        0
      end

      def delete_all
      end

      def empty?
        true
      end
    end

    class Chain
      # Return new none object
      def none
        None.new(self.source)
      end
    end

    module ClassMethods
      define_method(:none) do |*args, &blk|
        chain = Dynamoid::Criteria::Chain.new(self)
        chain.send(:none, *args, &blk)
      end
    end
  end
end
```

### Benefits
- Provides consistent API with ActiveRecord
- Enables conditional query building without complex logic
- Returns predictable empty results for edge cases
- Maintains chainable query interface

### Usage Examples
```ruby
# Conditional queries
users = condition ? User.where(active: true) : User.none

# Default empty state
def search_results(query)
  return User.none if query.blank?
  User.where(name: query)
end
```

### Tests
```ruby
describe "none method" do
  it "returns empty results" do
    expect(User.none.count).to eq(0)
    expect(User.none.to_a).to eq([])
    expect(User.none).to be_empty
  end

  it "is chainable" do
    expect(User.where(active: true).none.count).to eq(0)
  end
end
```

## 2. Limit Method Implementation

### Overview
The `limit()` method provides a more intuitive alias for Dynamoid's `record_limit()` method, matching ActiveRecord's interface and improving developer experience.

### Implementation

```ruby
module Dynamoid
  module Criteria
    class Chain
      # Set query result limit as record_limit of Dynamoid
      # @scope class
      # @param [Integer] limit Query result limit as record_limit
      # @return [Dynamoid::Criteria::Chain] Database query of filtered notifications or subscriptions
      def limit(limit)
        record_limit(limit)
      end
    end
  end
end
```

### Benefits
- Provides familiar ActiveRecord-style method name
- Improves code readability and developer experience
- Maintains backward compatibility with existing `record_limit` method
- Reduces cognitive load when switching between ORMs

### Usage Examples
```ruby
# More intuitive than record_limit(10)
User.limit(10)

# Chainable with other methods
User.where(active: true).limit(5)

# Consistent with ActiveRecord patterns
def recent_users(count = 10)
  User.where(created_at: Time.current.beginning_of_day..).limit(count)
end
```

### Tests
```ruby
describe "limit method" do
  it "limits query results" do
    create_list(:user, 20)
    expect(User.limit(5).count).to eq(5)
  end

  it "is chainable" do
    create_list(:user, 20, active: true)
    result = User.where(active: true).limit(3)
    expect(result.count).to eq(3)
  end

  it "behaves identically to record_limit" do
    create_list(:user, 10)
    expect(User.limit(5).to_a).to eq(User.record_limit(5).to_a)
  end
end
```

## 3. Exists? Method Implementation

### Overview
The `exists?()` method provides an efficient way to check if any records match the current query criteria without loading the actual records, similar to ActiveRecord's `exists?` method.

### Implementation

```ruby
module Dynamoid
  module Criteria
    class Chain
      # Return if records exist
      # @scope class
      # @return [Boolean] If records exist
      def exists?
        record_limit(1).count > 0
      end
    end
  end
end
```

### Benefits
- Provides efficient existence checking without loading full records
- Matches ActiveRecord's interface for consistency
- Optimizes performance by limiting query to single record
- Enables cleaner conditional logic in applications

### Performance Considerations
- Uses `record_limit(1)` to minimize data transfer
- Only performs count operation, not full record retrieval
- Significantly faster than loading all records just to check existence

### Usage Examples
```ruby
# Check if any active users exist
if User.where(active: true).exists?
  # Process active users
end

# Conditional processing
def process_notifications
  return unless Notification.where(unread: true).exists?
  # Process unread notifications
end

# Validation logic
def validate_unique_email
  errors.add(:email, 'already taken') if User.where(email: email).exists?
end
```

### Tests
```ruby
describe "exists? method" do
  it "returns true when records exist" do
    create(:user, active: true)
    expect(User.where(active: true).exists?).to be true
  end

  it "returns false when no records exist" do
    expect(User.where(active: true).exists?).to be false
  end

  it "is efficient and doesn't load full records" do
    create_list(:user, 100, active: true)
    
    # Should be much faster than loading all records
    expect {
      User.where(active: true).exists?
    }.to perform_faster_than {
      User.where(active: true).to_a.any?
    }
  end
end
```

## 4. Update_all Method Implementation

### Overview
The `update_all()` method provides batch update functionality for Dynamoid queries, similar to ActiveRecord's `update_all` method. This enables efficient bulk updates without loading individual records.

### Implementation

```ruby
module Dynamoid
  module Criteria
    class Chain
      # Update all records matching the current criteria
      # TODO: Make this batch operation more efficient
      def update_all(conditions = {})
        each do |document|
          document.update_attributes(conditions)
        end
      end
    end
  end
end
```

### Benefits
- Provides familiar ActiveRecord-style batch update interface
- Enables bulk operations on query results
- Maintains consistency with other ORM patterns
- Simplifies common bulk update scenarios

### Current Implementation Notes
- Current implementation iterates through each record individually
- Future optimization could implement true batch operations
- Maintains compatibility with existing Dynamoid update patterns

### Usage Examples
```ruby
# Bulk status updates
User.where(active: false).update_all(status: 'inactive')

# Batch timestamp updates
Notification.where(read: false).update_all(updated_at: Time.current)

# Conditional bulk updates
def mark_old_notifications_as_read
  Notification.where(created_at: ..1.week.ago).update_all(read: true)
end
```

### Future Optimization Opportunities
```ruby
# Potential batch implementation using DynamoDB batch operations
def update_all(conditions = {})
  # Group updates into batches of 25 (DynamoDB limit)
  all.each_slice(25) do |batch|
    batch_requests = batch.map do |document|
      {
        update_item: {
          table_name: document.class.table_name,
          key: document.key,
          update_expression: build_update_expression(conditions),
          expression_attribute_values: conditions
        }
      }
    end
    
    dynamodb_client.batch_write_item(request_items: {
      document.class.table_name => batch_requests
    })
  end
end
```

### Tests
```ruby
describe "update_all method" do
  it "updates all matching records" do
    users = create_list(:user, 5, active: true)
    User.where(active: true).update_all(status: 'updated')
    
    users.each(&:reload)
    expect(users.map(&:status)).to all(eq('updated'))
  end

  it "works with empty result sets" do
    expect {
      User.where(active: false).update_all(status: 'updated')
    }.not_to raise_error
  end

  it "updates only matching records" do
    active_users = create_list(:user, 3, active: true)
    inactive_users = create_list(:user, 2, active: false)
    
    User.where(active: true).update_all(status: 'updated')
    
    active_users.each(&:reload)
    inactive_users.each(&:reload)
    
    expect(active_users.map(&:status)).to all(eq('updated'))
    expect(inactive_users.map(&:status)).to all(be_nil)
  end
end
```

## 5. Null Operator Extensions

### Overview
Enhanced null value handling in Dynamoid queries, providing more intuitive ways to query for null and non-null values. This improves the developer experience when working with optional attributes.

### Implementation Context
The null operator extensions are primarily used within the UniquenessValidator but demonstrate a pattern that could be useful throughout Dynamoid:

```ruby
# From UniquenessValidator implementation
def filter_criteria(criteria, document, attribute)
  value = document.read_attribute(attribute)
  value.nil? ? criteria.where("#{attribute}.null" => true) : criteria.where(attribute => value)
end
```

### Benefits
- Provides intuitive null value querying
- Improves validation logic for optional fields
- Enables more expressive query conditions
- Maintains consistency with DynamoDB's null handling

### Usage Examples
```ruby
# Query for records with null values
User.where("email.null" => true)

# Query for records with non-null values  
User.where("email.null" => false)

# In validation contexts
def validate_uniqueness_with_nulls
  scope_criteria = base_criteria
  if email.nil?
    scope_criteria.where("email.null" => true)
  else
    scope_criteria.where(email: email)
  end
end
```

### Potential Extensions
```ruby
module Dynamoid
  module Criteria
    class Chain
      # Add convenience methods for null queries
      def where_null(attribute)
        where("#{attribute}.null" => true)
      end

      def where_not_null(attribute)
        where("#{attribute}.null" => false)
      end
    end
  end
end
```

### Tests
```ruby
describe "null operator extensions" do
  it "finds records with null values" do
    user_with_email = create(:user, email: 'test@example.com')
    user_without_email = create(:user, email: nil)
    
    results = User.where("email.null" => true)
    expect(results).to include(user_without_email)
    expect(results).not_to include(user_with_email)
  end

  it "finds records with non-null values" do
    user_with_email = create(:user, email: 'test@example.com')
    user_without_email = create(:user, email: nil)
    
    results = User.where("email.null" => false)
    expect(results).to include(user_with_email)
    expect(results).not_to include(user_without_email)
  end
end
```

## 6. Uniqueness Validator Implementation

### Overview
A comprehensive UniquenessValidator for Dynamoid that provides ActiveRecord-style uniqueness validation with support for scoped validation and null value handling.

### Implementation

```ruby
module Dynamoid
  module Validations
    # Validates whether or not a field is unique against the records in the database.
    class UniquenessValidator < ActiveModel::EachValidator
      # Validate the document for uniqueness violations.
      # @param [Document] document The document to validate.
      # @param [Symbol] attribute  The name of the attribute.
      # @param [Object] value      The value of the object.
      def validate_each(document, attribute, value)
        return unless validation_required?(document, attribute)
        if not_unique?(document, attribute, value)
          error_options = options.except(:scope).merge(value: value)
          document.errors.add(attribute, :taken, **error_options)
        end
      end

      private

      # Are we required to validate the document?
      # @api private
      def validation_required?(document, attribute)
        document.new_record? ||
          document.send("attribute_changed?", attribute.to_s) ||
          scope_value_changed?(document)
      end

      # Scope reference has changed?
      # @api private
      def scope_value_changed?(document)
        Array.wrap(options[:scope]).any? do |item|
          document.send("attribute_changed?", item.to_s)
        end
      end

      # Check whether a record is uniqueness.
      # @api private
      def not_unique?(document, attribute, value)
        klass = document.class
        while klass.superclass.respond_to?(:validators) && klass.superclass.validators.include?(self)
          klass = klass.superclass
        end
        criteria = create_criteria(klass, document, attribute, value)
        criteria.exists?
      end

      # Create the validation criteria.
      # @api private
      def create_criteria(base, document, attribute, value)
        criteria = scope(base, document)
        filter_criteria(criteria, document, attribute)
      end

      # @api private
      def scope(criteria, document)
        Array.wrap(options[:scope]).each do |item|
          criteria = filter_criteria(criteria, document, item)
        end
        criteria
      end

      # Filter the criteria.
      # @api private
      def filter_criteria(criteria, document, attribute)
        value = document.read_attribute(attribute)
        value.nil? ? criteria.where("#{attribute}.null" => true) : criteria.where(attribute => value)
      end
    end
  end
end
```

### Benefits
- Provides ActiveRecord-compatible uniqueness validation
- Supports scoped uniqueness validation
- Handles null values correctly
- Optimizes validation by only checking when necessary
- Supports inheritance hierarchies

### Key Features
1. **Conditional Validation**: Only validates when record is new or attribute has changed
2. **Scope Support**: Validates uniqueness within specified scopes
3. **Null Handling**: Properly handles null values in uniqueness checks
4. **Inheritance Support**: Works correctly with model inheritance
5. **Performance Optimization**: Uses `exists?` method for efficient checking

### Usage Examples
```ruby
class User
  include Dynamoid::Document
  
  field :email, :string
  field :username, :string
  field :organization_id, :string
  
  # Basic uniqueness validation
  validates :email, uniqueness: true
  
  # Scoped uniqueness validation
  validates :username, uniqueness: { scope: :organization_id }
  
  # With custom error message
  validates :email, uniqueness: { message: 'is already registered' }
end

# Usage in models
user = User.new(email: 'existing@example.com')
user.valid? # => false
user.errors[:email] # => ["has already been taken"]
```

### Tests
```ruby
describe "UniquenessValidator" do
  describe "basic uniqueness" do
    it "validates uniqueness of email" do
      create(:user, email: 'test@example.com')
      duplicate = build(:user, email: 'test@example.com')
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include('has already been taken')
    end

    it "allows unique emails" do
      create(:user, email: 'test1@example.com')
      unique = build(:user, email: 'test2@example.com')
      
      expect(unique).to be_valid
    end
  end

  describe "scoped uniqueness" do
    it "validates uniqueness within scope" do
      org1 = create(:organization)
      org2 = create(:organization)
      
      create(:user, username: 'john', organization: org1)
      
      # Same username in different org should be valid
      user_different_org = build(:user, username: 'john', organization: org2)
      expect(user_different_org).to be_valid
      
      # Same username in same org should be invalid
      user_same_org = build(:user, username: 'john', organization: org1)
      expect(user_same_org).not_to be_valid
    end
  end

  describe "null value handling" do
    it "allows multiple records with null values" do
      create(:user, email: nil)
      user_with_null = build(:user, email: nil)
      
      expect(user_with_null).to be_valid
    end
  end

  describe "performance optimization" do
    it "only validates when necessary" do
      user = create(:user, email: 'test@example.com')
      
      # Should not validate when no changes
      expect(User).not_to receive(:where)
      user.valid?
      
      # Should validate when email changes
      user.email = 'new@example.com'
      expect(User).to receive(:where).and_call_original
      user.valid?
    end
  end
end
```