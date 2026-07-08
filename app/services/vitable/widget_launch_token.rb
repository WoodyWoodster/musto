module Vitable
  class WidgetLaunchToken
    DEFAULT_TTL = 10.minutes
    HEADER = "X-Musto-Widget-Launch"
    PURPOSE = :vitable_widget_launch

    class << self
      def expires_at(ttl: DEFAULT_TTL)
        ttl.from_now
      end

      def issue(scope:, employer_id:, employee_id: nil, expires_at: self.expires_at)
        claims = WidgetLaunchTokenDto.new(
          scope:,
          employer_id:,
          employee_id:,
          issued_at: Time.current,
          expires_at:
        )

        verifier.generate(claims.to_claims)
      end

      def verify(token, at: Time.current)
        return WidgetLaunchTokenVerificationDto.failure("Signed widget launch token is required") if token.blank?

        claims = WidgetLaunchTokenDto.from_hash(verifier.verify(token))
        return WidgetLaunchTokenVerificationDto.failure("Signed widget launch token claims are invalid") unless claims.valid_claims?
        return WidgetLaunchTokenVerificationDto.failure("Signed widget launch token has expired") if claims.expired?(at:)

        WidgetLaunchTokenVerificationDto.success(claims)
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        WidgetLaunchTokenVerificationDto.failure("Signed widget launch token is invalid")
      rescue KeyError, ArgumentError
        WidgetLaunchTokenVerificationDto.failure("Signed widget launch token claims are invalid")
      end

      private

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
    end
  end
end
