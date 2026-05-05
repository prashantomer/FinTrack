class PlatformAccountSerializer < BaseSerializer
  def self.attributes(r)
    platform = assoc(r, :platform)
    {
      id:          r.id,
      nickname:    r.nickname,
      account_id:  r.account_id,
      platform_id: r.platform_id,
      platform:    platform ? { id: platform.id, name: platform.name, short_name: platform.short_name, type: platform.platform_type } : nil,
      created_at:  r.created_at
    }
  end
end
