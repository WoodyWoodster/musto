module Vitable
  WidgetLaunchTokenVerificationDto = Data.define(:claims, :error) do
    def self.success(claims)
      new(claims:, error: nil)
    end

    def self.failure(error)
      new(claims: nil, error:)
    end

    def success?
      error.blank?
    end
  end
end
