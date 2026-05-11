# == Schema Information
#
# Table name: users
#
#  id              :bigint           not null, primary key
#  currency_code   :string           default("INR"), not null
#  currency_locale :string           default("en-IN"), not null
#  email           :string           not null
#  first_name      :string           not null
#  is_active       :boolean          default(TRUE), not null
#  is_dummy        :boolean          default(FALSE), not null
#  is_superuser    :boolean          default(FALSE), not null
#  last_name       :string           not null
#  password_digest :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_email     (email) UNIQUE
#  index_users_on_is_dummy  (is_dummy)
#
class User < ApplicationRecord
  has_secure_password

  has_many :accounts,          dependent: :destroy
  has_many :term_accounts,     dependent: :destroy
  has_many :platform_accounts, dependent: :destroy
  has_many :user_instruments,  dependent: :destroy
  has_many :instruments,       through: :user_instruments
  has_many :investments,       dependent: :destroy
  has_many :transactions,      dependent: :destroy
  has_many :holdings,          dependent: :destroy
  has_many :folios,            -> { where(type: "Folio") },         class_name: "Folio",         foreign_key: :user_id
  has_many :equity_holdings,   -> { where(type: "EquityHolding") }, class_name: "EquityHolding", foreign_key: :user_id
  has_many :import_batches,    dependent: :destroy
  has_many :assistant_messages, dependent: :destroy
  has_one  :assistant_setting,  class_name: "UserAssistantSetting", dependent: :destroy

  def assistant_setting!
    assistant_setting || build_assistant_setting
  end

  validates :email,      presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name,  presence: true

  # `is_dummy = true` marks demo / seed / smoke-test accounts so reports and
  # admin counts can filter them out. Real users get the default (false).
  scope :real,  -> { where(is_dummy: false) }
  scope :dummy, -> { where(is_dummy: true) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_name=(name)
    parts = name.to_s.split(" ", 2)
    self.first_name = parts[0].presence || first_name
    self.last_name  = parts[1].presence || last_name
  end

  def tracked_instruments
    instruments
  end
end
