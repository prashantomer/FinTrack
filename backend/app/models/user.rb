class User < ApplicationRecord
  has_secure_password

  has_many :accounts,          dependent: :destroy
  has_many :term_accounts,     dependent: :destroy
  has_many :platform_accounts, dependent: :destroy
  has_many :user_instruments,  dependent: :destroy
  has_many :instruments,       through: :user_instruments
  has_many :investments,       dependent: :destroy
  has_many :transactions,      dependent: :destroy
  has_many :follios,           dependent: :destroy
  has_many :import_batches,    dependent: :destroy

  validates :email,      presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name,  presence: true

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
