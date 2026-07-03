class EnrollmentsController < ApplicationController
  def show
    @enrollment = Benefits::EnrollmentDetailQuery.new.call(params[:id])
  end

  def accept
    review("accepted")
  end

  def waive
    review("waived")
  end

  private

  def review(decision)
    dto = Benefits::ReviewEnrollmentDto.from_params(params, decision:)
    result = Benefits::ReviewEnrollmentCommand.new(dto:).call

    redirect_to(
      result.success? ? enrollment_path(result.record) : benefits_path,
      notice: result.success? ? "Enrollment #{decision}." : result.errors.to_sentence
    )
  end
end
