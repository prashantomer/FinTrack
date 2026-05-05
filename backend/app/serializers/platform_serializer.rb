class PlatformSerializer < BaseSerializer
  def self.attributes(r)
    {
      id:         r.id,
      name:       r.name,
      short_name: r.short_name,
      type:       r.platform_type,
      created_at: r.created_at
    }
  end
end
