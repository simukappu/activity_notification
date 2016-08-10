module ActivityNotification

  # Used to transform value from metadata to data.
  # Accepts Symbols, which it will send against context.
  # Accepts Procs, which it will execute with controller and context.
  # Both Symbols and Procs will be passed arguments of this method.
  def self.resolve_value(context, thing, *args)
    case thing
    when Symbol
      begin
        context.__send__(thing, ActivityNotification.get_controller, *args)
      rescue ArgumentError
        begin
          context.__send__(thing, ActivityNotification.get_controller)
        rescue ArgumentError
          context.__send__(thing)
        end
      end
    when Proc
      begin
        thing.call(ActivityNotification.get_controller, context, *args)
      rescue ArgumentError
        begin
          thing.call(ActivityNotification.get_controller, context)
        rescue ArgumentError
          thing.call(context)
        end
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

  module Common

    # Used to transform value from metadata to data which belongs model instance.
    # Accepts Symbols, which it will send against this instance.
    # Accepts Procs, which it will execute with this instance.
    # Both Symbols and Procs will be passed arguments of this method.
    def resolve_value(thing, *args)
      case thing
      when Symbol
        begin
          __send__(thing, *args)
        rescue ArgumentError => e
          __send__(thing)
        end
      when Proc
        begin
          thing.call(self, *args)
        rescue ArgumentError => e
          thing.call(self)
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

    def to_class_name
      self.class.name
    end

    def to_resource_name
      self.class.name.demodulize.singularize.underscore
    end

    def to_resources_name
      self.class.name.demodulize.pluralize.underscore
    end

    #TODO Is it the best solution?
    def printable_type
      "#{self.class.name.demodulize.humanize}"
    end

    #TODO Is it the best solution?
    def printable_name
      "#{self.printable_type} (#{id})"
    end

  end
end