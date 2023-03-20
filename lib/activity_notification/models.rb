require 'activity_notification/roles/acts_as_common'
require 'activity_notification/roles/acts_as_target'
require 'activity_notification/roles/acts_as_notifiable'
require 'activity_notification/roles/acts_as_notifier'
require 'activity_notification/roles/acts_as_group'

module ActivityNotification
  module Models
    extend ActiveSupport::Concern
    included do
      include ActivityNotification::ActsAsCommon
      include ActivityNotification::ActsAsTarget
      include ActivityNotification::ActsAsNotifiable
      include ActivityNotification::ActsAsNotifier
      include ActivityNotification::ActsAsGroup
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.class_eval { include ActivityNotification::Models }

  # https://github.com/simukappu/activity_notification/issues/166
  # https://discuss.rubyonrails.org/t/cve-2022-32224-possible-rce-escalation-bug-with-serialized-columns-in-active-record/81017
  if (Gem::Version.new("5.2.8.1") <= Rails.gem_version && Rails.gem_version < Gem::Version.new("6.0")) ||
    (Gem::Version.new("6.0.5.1") <= Rails.gem_version && Rails.gem_version < Gem::Version.new("6.1")) ||
    (Gem::Version.new("6.1.6.1") <= Rails.gem_version && Rails.gem_version < Gem::Version.new("7.0"))
    ActiveRecord::Base.yaml_column_permitted_classes ||= []
    ActiveRecord::Base.yaml_column_permitted_classes << ActiveSupport::HashWithIndifferentAccess
    ActiveRecord::Base.yaml_column_permitted_classes << ActiveSupport::TimeWithZone
    ActiveRecord::Base.yaml_column_permitted_classes << ActiveSupport::TimeZone
    ActiveRecord::Base.yaml_column_permitted_classes << Symbol
    ActiveRecord::Base.yaml_column_permitted_classes << Time
  elsif Gem::Version.new("7.0.3.1") <= Rails.gem_version
    ActiveRecord.yaml_column_permitted_classes ||= []
    ActiveRecord.yaml_column_permitted_classes << ActiveSupport::HashWithIndifferentAccess
    ActiveRecord.yaml_column_permitted_classes << ActiveSupport::TimeWithZone
    ActiveRecord.yaml_column_permitted_classes << ActiveSupport::TimeZone
    ActiveRecord.yaml_column_permitted_classes << Symbol
    ActiveRecord.yaml_column_permitted_classes << Time
  end
end
