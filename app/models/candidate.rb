class Candidate < ApplicationRecord
  STAGES = %w[applied screening interview offer accepted hired rejected withdrawn].freeze

  belongs_to :job_opening
  belongs_to :employee, optional: true

  has_one :employer, through: :job_opening

  validates :first_name, :last_name, :email, :source, :stage, :applied_on, presence: true
  validates :stage, inclusion: { in: STAGES }
  validates :email, uniqueness: { scope: :job_opening_id }
  validates :score, numericality: { greater_than_or_equal_to: 0 }
  validates :compensation_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :active_pipeline, -> { where(stage: %w[applied screening interview offer accepted]) }
  scope :accepted, -> { where(stage: "accepted") }
  scope :offerable, -> { where(stage: %w[applied screening interview]) }

  def full_name
    [ first_name, last_name ].join(" ")
  end

  def offerable?
    stage.in?(%w[applied screening interview])
  end

  def accepted?
    stage == "accepted"
  end

  def hired?
    stage == "hired"
  end

  def inactive?
    stage.in?(%w[hired rejected withdrawn])
  end
end
