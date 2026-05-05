class Bank < ApplicationRecord
  has_many :accounts, dependent: :restrict_with_error

  validates :name,       presence: true
  validates :short_name, presence: true, uniqueness: true, length: { maximum: 6 }
end
