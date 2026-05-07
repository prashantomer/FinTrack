# == Schema Information
#
# Table name: platforms
#
#  id            :bigint           not null, primary key
#  is_system     :boolean          default(FALSE), not null
#  name          :string(100)      not null
#  platform_type :string           not null
#  short_name    :string(20)       not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_platforms_on_short_name  (short_name) UNIQUE
#
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
