module Vitable
  WebhookRequestDto = Data.define(:raw_body, :headers, :payload) do
    HEADER_NAMES = [
      "X-Vitable-Signature",
      "Vitable-Signature",
      "X-Vitable-Webhook-Signature",
      "X-Vitable-Timestamp",
      "Vitable-Timestamp"
    ].freeze

    def self.from_request(request, payload)
      new(
        raw_body: request.raw_post.to_s,
        headers: headers_from(request),
        payload: ApplicationDto.coerce_hash(payload)
      )
    end

    def header(name)
      headers[name] || headers[name.to_s.downcase]
    end

    private_class_method def self.headers_from(request)
      HEADER_NAMES.filter_map do |name|
        value = request.headers[name]
        [ name, value ] if value.present?
      end.to_h
    end
  end
end
