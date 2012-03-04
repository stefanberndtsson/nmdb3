class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :use_ssl
  
  private
  SECURE_ACTIONS = {
    :user => ["login", "verify_login", "prefs", "save", "register", "create"]
  }
    
  # Called as a before_filter in controllers that have some https:// actions
  def use_ssl
    if should_use_ssl? && !request.ssl?
      redirect_to params.merge(:protocol => 'https')
    elsif !should_use_ssl? && request.ssl?
      redirect_to params.merge(:protocol => 'http')
    end
  end

  def should_use_ssl?
    action = params[:action]
    controller = params[:controller]
    return false if !action && !controller
    return false if RAILS_ENV != "production"
    
    if(SECURE_ACTIONS[controller.to_sym] && 
       SECURE_ACTIONS[controller.to_sym].include?(action))
      return true
    else
      return false
    end
  end
end
