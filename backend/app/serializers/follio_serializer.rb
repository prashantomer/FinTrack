class FollioSerializer < BaseSerializer
  def self.attributes(r)
    ui = assoc(r, :user_instrument)
    pa = assoc(r, :platform_account)
    {
      id:                   r.id,
      follio_id:            r.folio_number,
      folio_number:         r.folio_number,
      user_id:              r.user_id,
      user_instrument_id:   r.user_instrument_id,
      platform_account_id:  r.platform_account_id,
      notes:                r.notes,
      created_at:           r.created_at,
      user_instrument:      ui ? UserInstrumentSerializer.one(ui) : nil,
      platform_account:     pa ? PlatformAccountSerializer.one(pa) : nil
    }
  end
end
