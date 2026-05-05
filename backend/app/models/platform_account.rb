class PlatformAccount < ApplicationRecord
  belongs_to :user
  belongs_to :platform

  has_many :investments, dependent: :nullify

  validates :nickname, presence: true
end
