module ActivityNotification

  # Used to transform value from metadata to data.
  # Accepts Symbols, which it will send against context.
  # Accepts Procs, which it will execute with controller and context.
  # Both Symbols and Procs will be passed arguments of this method.
  # Also accepts Hash of these Symbols or Procs.
  # If any other value will be passed, returns original value.
  #
  # @param [Object] context Context to resolve parameter, which is usually target or notificable model
  # @param [Symbol, Proc, Hash, Object] thing Symbol or Proc to resolve parameter
  # @param [Array] args Arguments to pass to thing as method
  # @return [Object] Resolved parameter value
  def self.resolve_value(context, thing, *args)
    case thing
    when Symbol
      symbol_method = context.method(thing)
      if symbol_method.arity > 1
        if args.last.kind_of?(Hash)
          symbol_method.call(ActivityNotification.get_controller, *args[0...-1], **args[-1])
        else
          symbol_method.call(ActivityNotification.get_controller, *args)
        end
      elsif symbol_method.arity > 0
        symbol_method.call(ActivityNotification.get_controller)
      else
        symbol_method.call
      end
    when Proc
      if thing.arity > 2
        thing.call(ActivityNotification.get_controller, context, *args)
      elsif thing.arity > 1
        thing.call(ActivityNotification.get_controller, context)
      elsif thing.arity > 0
        thing.call(context)
      else
        thing.call
      end
    when Hash
      thing.dup.tap do |hash|
        hash.each do |key, value|
          hash[key] = ActivityNotification.resolve_value(context, value, *args)
        end
      end
    else
      thing
    end
  end

  # MongoDB query operators which execute JavaScript on the database server.
  JAVASCRIPT_QUERY_OPERATORS = %w[$where $function $accumulator].freeze

  # Validates a :custom_filter value before it is passed to the ORM query layer.
  # custom_filter is a trusted input written by the application developer and
  # must not be built from request parameters. This validation rejects the forms
  # that run raw SQL or server-side JavaScript:
  # - A String, since ActiveRecord's where treats it as a raw SQL fragment
  # - An Array without bind parameters (e.g. ["1=1"]), which is also a raw SQL fragment
  # - A Hash containing MongoDB JavaScript operators ($where, $function and $accumulator)
  # The supported forms are an Array of a SQL fragment with bind parameters
  # (e.g. ["created_at >= ?", time]) or a Hash of conditions.
  # @param [Array, Hash] custom_filter Custom filter value
  # @return [Array, Hash] The same value when it is safe to use
  # @raise [ArgumentError] When custom_filter is not in the supported forms
  def self.validate_custom_filter(custom_filter)
    valid =
      case custom_filter
      when Array then custom_filter.size >= 2 && custom_filter.first.is_a?(String)
      when Hash  then !contains_javascript_query_operator?(custom_filter)
      else false
      end
    unless valid
      raise ArgumentError,
        ":custom_filter must be an array of a SQL fragment and bind parameters " \
        "(e.g. [\"created_at >= ?\", time]) or a hash of conditions without JavaScript operators"
    end
    custom_filter
  end

  # Returns whether the value contains MongoDB query operators which execute JavaScript.
  # @param [Object] value Value to check
  # @return [Boolean] Whether the value contains JavaScript query operators
  def self.contains_javascript_query_operator?(value)
    case value
    when Hash
      value.any? { |k, v| JAVASCRIPT_QUERY_OPERATORS.include?(k.to_s) || contains_javascript_query_operator?(v) }
    when Array
      value.any? { |v| contains_javascript_query_operator?(v) }
    else
      false
    end
  end
  private_class_method :contains_javascript_query_operator?

  # Casts to indifferent hash
  # @param [ActionController::Parameters, Hash] hash
  # @return [HashWithIndifferentAccess] Converted indifferent hash
  def self.cast_to_indifferent_hash(hash = {})
    # This is the typical (not-ActionView::TestCase) code path.
    hash = hash.to_unsafe_h if hash.respond_to?(:to_unsafe_h)
    # In Rails 5 to_unsafe_h returns a HashWithIndifferentAccess, in Rails 4 it returns Hash
    hash = hash.with_indifferent_access if hash.instance_of? Hash
    hash
  end

  # Common module included in target and notifiable model.
  # Provides methods to resolve parameters from configured field or defined method.
  # Also provides methods to convert into resource name or class name as string.
  module Common

    # Used to transform value from metadata to data which belongs model instance.
    # Accepts Symbols, which it will send against this instance,
    # Accepts Procs, which it will execute with this instance.
    # Both Symbols and Procs will be passed arguments of this method.
    # Also accepts Hash of these Symbols or Procs.
    # If any other value will be passed, returns original value.
    #
    # @param [Symbol, Proc, Hash, Object] thing Symbol or Proc to resolve parameter
    # @param [Array] args Arguments to pass to thing as method
    # @return [Object] Resolved parameter value
    def resolve_value(thing, *args)
      case thing
      when Symbol
        symbol_method = method(thing)
        if symbol_method.arity > 0
          if args.last.kind_of?(Hash)
            symbol_method.call(*args[0...-1], **args[-1])
          else
            symbol_method.call(*args)
          end
        else
          symbol_method.call
        end
      when Proc
        if thing.arity > 1
          thing.call(self, *args)
        elsif thing.arity > 0
          thing.call(self)
        else
          thing.call
        end
      when Hash
        thing.dup.tap do |hash|
          hash.each do |key, value|
            hash[key] = resolve_value(value, *args)
          end
        end
      else
        thing
      end
    end

    # Converts to class name.
    # This function returns base_class name for STI models if the class responds to base_class method.
    # @see https://github.com/simukappu/activity_notification/issues/89
    # @see https://github.com/simukappu/activity_notification/pull/139
    # @return [String] Class name
    def to_class_name
      self.class.respond_to?(:base_class) ? self.class.base_class.name : self.class.name
    end

    # Converts to singularized model name (resource name).
    # @return [String] Singularized model name (resource name)
    def to_resource_name
      self.to_class_name.demodulize.singularize.underscore
    end

    # Converts to pluralized model name (resources name).
    # @return [String] Pluralized model name (resources name)
    def to_resources_name
      self.to_class_name.demodulize.pluralize.underscore
    end

    # Converts to printable model type name to be humanized.
    # @return [String] Printable model type name
    # @todo Is this the best to make readable?
    def printable_type
      "#{self.to_class_name.demodulize.humanize}"
    end

    # Converts to printable model name to show in view or email.
    # @return [String] Printable model name
    def printable_name
      "#{self.printable_type} (#{id})"
    end
  end
end
