class ApplicationDto
  def self.coerce_hash(value)
    value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
  end
end
