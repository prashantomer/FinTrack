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
