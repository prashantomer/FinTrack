class Platform < ApplicationRecord
  has_many :platform_accounts, dependent: :restrict_with_error

  enum :platform_type, {
    broker:      "broker",
    mf_platform: "mf_platform",
    direct:      "direct",
    other:       "other"
  }, validate: true

  validates :name,       presence: true
  validates :short_name, presence: true, uniqueness: true
end
