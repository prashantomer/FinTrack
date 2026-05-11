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
class UserSerializer < BaseSerializer
  def self.attributes(r)
    {
      id:              r.id,
      email:           r.email,
      first_name:      r.first_name,
      last_name:       r.last_name,
      full_name:       r.full_name,
      is_active:       r.is_active,
      is_superuser:    r.is_superuser,
      is_dummy:        r.is_dummy,
      currency_code:   r.currency_code,
      currency_locale: r.currency_locale,
      created_at:      r.created_at
    }
  end
end
