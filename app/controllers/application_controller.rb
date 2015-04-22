class ApplicationController < ActionController::Base

  include SessionsHelper

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  helper_method :page_identifier

  def page_identifier
    # admin/courses#index => admin-courses_index
    controller = params[:controller].tr("/","-")
    action = params[:action]
    "#{controller}_#{action}"
  end

  def store_location(location = nil)
    location ||= request.fullpath
    session[:location] = location
  end

  def redirect_to_back_or_default(location = nil)
    if session[:location].present?
      redirect_to session.delete(:location)
    else
      redirect_to (location || root_path)
    end
  end

  def render_404(msg="Not Found")
    raise ActionController::RoutingError.new(msg)
  end

  # @params [String] msg
  # @params [ActiveModel::Errors | (Hash => String|Array<String>)] errors
  def render_400(msg,errors=nil)
    if errors.is_a?(ActiveModel::Errors)
      errors = errors.to_hash
    end

    if request.xhr?
      render json: {
        msg: msg,
        errors: errors
      }, status: :bad_request
    end
  end

  private

  def ensure_trailing_slash
    redirect_to url_for(params.merge(:trailing_slash => true)), :status => 301 unless trailing_slash?
  end

  def trailing_slash?
    request.env['REQUEST_URI'].match(/[^\?]+/).to_s.last == '/'
  end

end
