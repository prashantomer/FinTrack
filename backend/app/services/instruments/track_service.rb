module Instruments
  class TrackService
    def initialize(user, instrument)
      @user       = user
      @instrument = instrument
    end

    # `backfill:` controls whether to enqueue a 1-year price-history backfill
    # the *first* time this user-instrument pair is created. Default true for
    # direct UI/API tracking — the user explicitly subscribed, so we want
    # their charts populated without waiting for the daily cron. The CSV
    # importer overrides to false because it can create dozens of new tracks
    # in a single batch; we don't want to fan out 250+ jobs per row. Bulk
    # paths can run `instruments:backfill_prices` once after the import.
    def track(backfill: true)
      ui = @user.user_instruments.find_or_create_by!(instrument: @instrument)
      if backfill && ui.previously_new_record?
        Instruments::FirstTimeBackfillJob.perform_later(@instrument.id)
      end
      ui
    end

    def untrack
      @user.user_instruments.find_by(instrument: @instrument)&.destroy
    end
  end
end
