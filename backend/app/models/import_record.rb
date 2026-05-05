class ImportRecord < ApplicationRecord
  belongs_to :import_batch
  belongs_to :importable, polymorphic: true, optional: true

  enum :status, { ok: "ok", error: "error", skipped: "skipped" }, validate: true
end
