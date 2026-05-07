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
