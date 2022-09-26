class ApplicationController < ActionController::Base

  private

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  def after_inactive_sign_up_path_for(resource_or_scope)
    new_user_session_path
  end

end
