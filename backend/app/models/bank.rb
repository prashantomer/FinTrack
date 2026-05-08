# == Schema Information
#
# Table name: banks
#
#  id         :bigint           not null, primary key
#  is_system  :boolean          default(FALSE), not null
#  name       :string(100)      not null
#  short_name :string(6)        not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_banks_on_short_name  (short_name) UNIQUE
#
class Bank < ApplicationRecord
  has_many :accounts, dependent: :restrict_with_error

  validates :name,       presence: true
  validates :short_name, presence: true, uniqueness: true, length: { maximum: 6 }
end
