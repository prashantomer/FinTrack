# == Schema Information
#
# Table name: user_instruments
#
#  id            :bigint           not null, primary key
#  added_at      :datetime         not null
#  instrument_id :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_instruments_on_instrument_id              (instrument_id)
#  index_user_instruments_on_user_id                    (user_id)
#  index_user_instruments_on_user_id_and_instrument_id  (user_id,instrument_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (instrument_id => instruments.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class UserInstrumentSerializer < BaseSerializer
  def self.attributes(r)
    instrument = assoc(r, :instrument)
    {
      id:            r.id,
      user_id:       r.user_id,
      instrument_id: r.instrument_id,
      added_at:      r.added_at,
      instrument:    instrument ? InstrumentSerializer.one(instrument) : nil
    }
  end
end
