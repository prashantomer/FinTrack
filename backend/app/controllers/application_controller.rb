class ApplicationController < ActionController::API
  include Authenticatable
  include Responder

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid,  with: :unprocessable

  private

  def not_found(e)
    render_error(message: e.message, status: :not_found)
  end

  def unprocessable(e)
    render_error(message: "Validation failed", errors: e.record.errors.to_hash, status: :unprocessable_content)
  end
end
