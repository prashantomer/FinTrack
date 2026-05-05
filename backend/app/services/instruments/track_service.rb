module Instruments
  class TrackService
    def initialize(user, instrument)
      @user       = user
      @instrument = instrument
    end

    def track
      @user.user_instruments.find_or_create_by!(instrument: @instrument)
    end

    def untrack
      @user.user_instruments.find_by(instrument: @instrument)&.destroy
    end
  end
end
