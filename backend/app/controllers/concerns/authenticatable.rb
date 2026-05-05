module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_token
    return render_unauthorized unless token

    payload = JsonWebToken.decode(token)
    return render_unauthorized unless payload

    @current_user = User.find_by(id: payload["user_id"])
    render_unauthorized unless @current_user
  end

  def current_user
    @current_user
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
