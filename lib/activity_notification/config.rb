module ActivityNotification
  # Class used to initialize configuration object.
  class Config
    attr_accessor :enabled,
                  :table_name,
                  :mailer_sender,
                  :mailer,
                  :parent_mailer,
                  :parent_controller,
                  :opened_limit

    def initialize
      @enabled           = true
      @table_name        = "notifications"
      @mailer_sender     = nil
      @mailer            = "ActivityNotification::Mailer"
      @parent_mailer     = 'ActionMailer::Base'
      @parent_controller = 'ApplicationController'
      @opened_limit      = 10
    end

  end
end
