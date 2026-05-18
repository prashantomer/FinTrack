module Responder
  extend ActiveSupport::Concern

  def render_success(data:, status: :ok, meta_data: {})
    render json: {
      success:    true,
      code:       Rack::Utils.status_code(status),
      request_id: request.uuid,
      data:       serialize_data(data),
      meta_data:  meta_data
    }, status: status
  end

  def render_created(data:, meta_data: {})
    render_success(data: data, status: :created, meta_data: meta_data)
  end

  def render_error(message:, errors: nil, status: :unprocessable_content)
    body = {
      success:    false,
      code:       Rack::Utils.status_code(status),
      request_id: request.uuid,
      data:       nil,
      meta_data:  {},
      error:      message
    }
    body[:errors] = errors if errors.present?
    render json: body, status: status
  end

  private

  def serialize_data(data)
    return data if data.nil? || data.is_a?(Hash)

    if data.is_a?(ActiveRecord::Base)
      serializer = "#{data.class.name}Serializer".safe_constantize
      return serializer ? serializer.one(data) : data
    end

    if data.is_a?(ActiveRecord::Relation) || data.is_a?(Array)
      first = data.first
      return data if first.nil? || !first.is_a?(ActiveRecord::Base)
      serializer = "#{first.class.name}Serializer".safe_constantize
      return serializer ? serializer.many(data) : data
    end

    data
  end
end
