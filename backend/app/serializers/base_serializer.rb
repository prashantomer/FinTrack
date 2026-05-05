class BaseSerializer
  def self.one(record)
    return nil if record.nil?
    attributes(record)
  end

  def self.many(collection)
    collection.map { |r| one(r) }
  end

  private_class_method def self.assoc(record, name)
    record.association(name).loaded? ? record.public_send(name) : nil
  end
end
