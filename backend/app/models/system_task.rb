# == Schema Information
#
# Table name: system_tasks
#
#  id                  :bigint           not null, primary key
#  last_completed_at   :datetime
#  last_completed_date :date
#  last_error          :text
#  last_status         :string(16)
#  name                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_system_tasks_on_name  (name) UNIQUE
#
class SystemTask < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  STATUSES = %w[ok error].freeze
  validates :last_status, inclusion: { in: STATUSES, allow_nil: true }

  # Ergonomic accessor for the daily price + P&L job and any future schedules.
  def self.named(name)
    find_or_create_by!(name: name)
  end

  def stale_for?(date)
    last_completed_date.nil? || last_completed_date < date
  end

  def mark_ok!(at: Time.current, date: Date.current)
    update!(last_completed_at: at, last_completed_date: date, last_status: "ok", last_error: nil)
  end

  def mark_error!(message, at: Time.current)
    update!(last_completed_at: at, last_status: "error", last_error: message.to_s.first(2_000))
  end
end
