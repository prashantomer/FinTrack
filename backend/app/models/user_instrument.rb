class UserInstrument < ApplicationRecord
  belongs_to :user
  belongs_to :instrument

  has_many :follios,     dependent: :destroy
  has_many :investments, dependent: :nullify

  validates :user_id, uniqueness: { scope: :instrument_id }
end
