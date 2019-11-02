module ActivityNotification
  class ConfigError < StandardError; end
  class DeleteRestrictionError < StandardError; end
  class NotifiableNotFoundError < StandardError; end
  class InvalidParameterError < StandardError; end
end
