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
      currency_code:   r.currency_code,
      currency_locale: r.currency_locale,
      created_at:      r.created_at
    }
  end
end
