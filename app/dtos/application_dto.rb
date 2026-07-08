class ApplicationDto
  def self.coerce_hash(value)
    value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
  end

  def self.id_from(params, key = :id)
    coerce_hash(params).fetch(key).to_i
  end

  def self.strict_positive_integer?(value)
    case value
    when Integer
      value.positive?
    when String
      value.match?(/\A[1-9]\d*\z/)
    else
      false
    end
  end
end
