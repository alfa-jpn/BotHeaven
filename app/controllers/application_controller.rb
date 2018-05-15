class ApplicationController < ActionController::Base
  include Authenticatable

  protect_from_forgery with: :exception

  before_action :set_current_user
  before_action :require_login_in_private

  def set_current_user
    @current_user = current_user
  end

  def require_login_in_private
    authenticated! if ENV['PRIVATE_MODE'] == '1'
  end
end
