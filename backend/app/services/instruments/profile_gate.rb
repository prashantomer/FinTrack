module Instruments
  # Decides whether the current user is allowed to view a per-instrument
  # profile page. Tracked profiles (anything in user_instruments or
  # investments.instrument_id) always pass. Untracked profiles fall through
  # to the project-level mode + per-instrument flag.
  #
  # Used by the four `/instruments/:id/{position,lots,transactions,price-history}`
  # endpoints. Disallowed requests render 404 (don't leak existence with 403).
  module ProfileGate
    module_function

    def allowed?(user, instrument)
      return false if instrument.nil? || user.nil?

      return true if tracked_by?(user, instrument)

      case mode
      when "on"             then true
      when "per_instrument" then !!instrument.profile_enabled
      else                       false
      end
    end

    def tracked_by?(user, instrument)
      return true if user.user_instruments.exists?(instrument_id: instrument.id)
      user.investments.joins(:user_instrument)
          .exists?(user_instruments: { instrument_id: instrument.id })
    end

    def mode
      Rails.application.config.x.fintrack&.untracked_profile_mode || "off"
    end
  end
end
