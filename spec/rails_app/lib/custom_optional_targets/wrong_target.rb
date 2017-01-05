module CustomOptionalTarget
  # Wrong optional target implementation for tests.
  class WrongTarget
    def initialize_target(options = {})
    end

    def notify(notification, options = {})
    end
  end
end