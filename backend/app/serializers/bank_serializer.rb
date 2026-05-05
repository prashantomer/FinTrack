class BankSerializer < BaseSerializer
  def self.attributes(r)
    {
      id:         r.id,
      name:       r.name,
      short_name: r.short_name,
      is_system:  r.is_system,
      created_at: r.created_at
    }
  end
end
