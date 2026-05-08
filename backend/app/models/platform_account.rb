# == Schema Information
#
# Table name: platform_accounts
#
#  id          :bigint           not null, primary key
#  nickname    :string(100)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :string(50)
#  platform_id :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_platform_accounts_on_platform_id  (platform_id)
#  index_platform_accounts_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (platform_id => platforms.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class PlatformAccount < ApplicationRecord
  belongs_to :user
  belongs_to :platform

  has_many :investments, dependent: :nullify

  validates :nickname, presence: true
end
