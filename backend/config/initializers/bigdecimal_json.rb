class BigDecimal
  def as_json(options = nil)
    to_f
  end
end
