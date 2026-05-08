# == Schema Information
#
# Table name: holding_snapshots
#
#  id                  :bigint           not null, primary key
#  avg_buy_price       :decimal(14, 4)
#  current_value       :decimal(14, 2)
#  is_closed           :boolean          default(FALSE), not null
#  market_price        :decimal(14, 4)
#  realized_gain       :decimal(14, 2)
#  snapshot_date       :date             not null
#  total_invested      :decimal(14, 2)
#  total_units         :decimal(15, 4)
#  unrealized_gain     :decimal(14, 2)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  holding_id          :bigint           not null
#  platform_account_id :bigint           not null
#  user_id             :bigint           not null
#  user_instrument_id  :bigint           not null
#
# Indexes
#
#  idx_on_platform_account_id_snapshot_date_145f899a61   (platform_account_id,snapshot_date)
#  index_holding_snapshots_on_holding_id                 (holding_id)
#  index_holding_snapshots_on_platform_account_id        (platform_account_id)
#  index_holding_snapshots_on_user_id                    (user_id)
#  index_holding_snapshots_on_user_id_and_snapshot_date  (user_id,snapshot_date)
#  index_holding_snapshots_on_user_instrument_id         (user_instrument_id)
#  uq_holding_snapshot_per_day                           (holding_id,snapshot_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (holding_id => holdings.id) ON DELETE => cascade
#  fk_rails_...  (platform_account_id => platform_accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (user_instrument_id => user_instruments.id) ON DELETE => cascade
#
class HoldingSnapshot < ApplicationRecord
  belongs_to :user
  belongs_to :holding
  belongs_to :platform_account
  belongs_to :user_instrument

  validates :snapshot_date, presence: true
  validates :holding_id, uniqueness: { scope: :snapshot_date }

  scope :on,         ->(date) { where(snapshot_date: date) }
  scope :for_user,   ->(u)    { where(user_id: u.is_a?(User) ? u.id : u) }
  scope :since,      ->(date) { where("snapshot_date >= ?", date) }
end
