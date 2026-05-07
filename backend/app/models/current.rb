class Current < ActiveSupport::CurrentAttributes
  # When true, Investment after_commit callbacks skip enqueueing
  # `Holdings::RefreshJob`. Used by bulk imports that prefer to enqueue a
  # single sweep at the end of the batch instead of one job per row.
  attribute :skip_holding_refresh
end
