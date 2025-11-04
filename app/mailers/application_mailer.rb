class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "noreply@accounts.baehubapp.com")
  layout "mailer"
end
