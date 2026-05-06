module Api
  module V1
    module Assistant
      class SettingsController < ApplicationController
        before_action :load_setting

        # GET /api/v1/assistant/setting
        def show
          render_success(data: serialize(@setting))
        end

        # PATCH /api/v1/assistant/setting
        def update
          attrs = setting_params
          # When the client sends an empty/blank api_key, leave the existing one untouched.
          attrs.delete(:api_key) if attrs.key?(:api_key) && attrs[:api_key].to_s.strip.empty?

          @setting.assign_attributes(attrs)
          @setting.save!
          render_success(data: serialize(@setting))
        end

        # POST /api/v1/assistant/setting/test
        # Validates the supplied (or saved) credentials WITHOUT persisting.
        def test
          probe = build_probe_setting
          provider = ::Assistants::Provider.for(probe)
          latency_ms = provider.ping
          @setting.record_test_result(:ok, latency_ms: latency_ms) if probe_uses_saved?
          render_success(data: { ok: true, latency_ms: latency_ms })
        rescue ::Assistants::Errors::ProviderError => e
          @setting.record_test_result(:error, error: e.message) if probe_uses_saved?
          render_success(
            data: {
              ok: false,
              code: e.code,
              provider: e.provider,
              error_class: e.class.name.demodulize,
              message: e.message
            }
          )
        end

        private

        def load_setting
          @setting = current_user.assistant_setting || current_user.build_assistant_setting
          @setting.save! if @setting.new_record?
        end

        def setting_params
          params.permit(:provider, :model, :api_key, :base_url, :daily_limit)
        end

        # Either the in-flight form values OR the persisted settings, depending on
        # whether the client sent a body. We DON'T persist the probe attributes.
        def build_probe_setting
          probe = ::UserAssistantSetting.new(@setting.attributes.except("id", "created_at", "updated_at"))
          probe.user = current_user
          if params[:provider].present? || params[:model].present? || params[:base_url].present? || params[:api_key].present?
            probe.assign_attributes(setting_params.except(:daily_limit))
            probe.api_key = @setting.api_key if probe.api_key.blank? && @setting.api_key.present?
            @uses_saved = false
          else
            @uses_saved = true
          end
          probe
        end

        def probe_uses_saved?
          @uses_saved
        end

        def serialize(setting)
          {
            provider:           setting.provider,
            model:              setting.model,
            base_url:           setting.base_url,
            daily_limit:        setting.daily_limit,
            effective_provider: setting.effective_provider,
            effective_model:    setting.effective_model,
            effective_base_url: setting.effective_base_url,
            has_api_key:        setting.api_key_present?,
            api_key_tail:       setting.api_key_tail,
            requires_api_key:   setting.requires_api_key?,
            configured:         setting.configured?,
            last_tested_at:     setting.last_tested_at,
            last_test_status:   setting.last_test_status,
            last_test_error:    setting.last_test_error
          }
        end
      end
    end
  end
end
