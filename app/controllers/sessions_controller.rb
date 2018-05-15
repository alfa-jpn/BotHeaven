class SessionsController < ApplicationController
  before_action :require_auth!, only: [:create]
  before_action :authenticated!, only: [:destroy]
  skip_before_action :require_login_in_private

  def new
    redirect_to '/auth/slack'
  end

  def create
    user = User.find_or_create!(auth['uid'])
    update_user!(user)
    login(user, auth.credentials.token)
    redirect_to root_path
  end

  def destroy
    logout
    redirect_to root_path
  end

  private
  def auth
    request.env['omniauth.auth']
  end

  def require_auth!
    redirect_to root_path unless auth
    redirect_to root_path unless auth['provider'] == 'slack'
  end

  def update_user!(user)
    user.update!(
      name:      auth['info']['nickname'],
      image_url: auth['info']['image'],
    )
  end
end
