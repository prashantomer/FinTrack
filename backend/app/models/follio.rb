class Follio < ApplicationRecord
  belongs_to :user
  belongs_to :user_instrument
  belongs_to :platform_account

  validates :folio_number, presence: true
  validates :user_instrument_id, uniqueness: { scope: :platform_account_id }
end
