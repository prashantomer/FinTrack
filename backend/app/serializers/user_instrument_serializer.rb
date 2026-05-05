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
