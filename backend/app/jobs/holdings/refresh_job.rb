module Holdings
  # Sidekiq-backed wrapper around {Holdings::RefreshService}. The Investment
  # callback enqueues this so the request thread can return immediately;
  # imports enqueue a single full-user sweep after the batch finishes.
  #
  # Three call shapes:
  #   Holdings::RefreshJob.perform_later(user_id, ui_id, pa_id)  # one position
  #   Holdings::RefreshJob.perform_later(user_id, ui_id)         # one user_instrument across platforms
  #   Holdings::RefreshJob.perform_later(user_id)                # full user sweep
  class RefreshJob < ApplicationJob
    queue_as :default

    def perform(user_id, user_instrument_id = nil, platform_account_id = nil)
      user = User.find_by(id: user_id)
      return unless user

      if user_instrument_id && platform_account_id
        Holdings::RefreshService.new(user, user_instrument_id, platform_account_id).call
      elsif user_instrument_id
        Holdings::RefreshService.refresh_for_user_instrument(user, user_instrument_id)
      else
        Holdings::RefreshService.refresh_all_for(user)
      end
    end
  end
end
