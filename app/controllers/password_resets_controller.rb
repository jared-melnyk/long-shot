# frozen_string_literal: true

class PasswordResetsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :edit, :update ]

  def new
  end

  def create
    email = params.permit(:email).fetch(:email, "").to_s.strip.downcase
    user = User.find_by(email: email)
    if user
      raw_token = user.generate_password_reset_token
      UserMailer.password_reset(user, raw_token).deliver_later
    end
    redirect_to login_path, notice: "If an account exists for that email, we've sent a link to reset your password. Check your inbox and spam."
  end
end
