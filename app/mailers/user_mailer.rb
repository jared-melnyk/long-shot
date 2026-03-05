# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset(user, raw_token)
    @user = user
    @reset_url = edit_password_reset_url(token: raw_token)
    mail to: user.email, subject: "Reset your password"
  end
end
