module Onboarding
  LaneDto = Data.define(
    :key,
    :label,
    :owner,
    :total_count,
    :open_count,
    :overdue_count,
    :completion_rate,
    :status,
    :accent
  ) do
    def self.from_tasks(owner, tasks)
      open_tasks = tasks.reject(&:complete?)
      total_count = tasks.count

      new(
        key: owner,
        label: "#{owner.to_s.humanize} lane",
        owner:,
        total_count:,
        open_count: open_tasks.count,
        overdue_count: open_tasks.count(&:overdue?),
        completion_rate: total_count.zero? ? 100 : (((total_count - open_tasks.count).to_f / total_count) * 100).round,
        status: lane_status(open_tasks),
        accent: accent_for(owner)
      )
    end

    def clear?
      open_count.zero?
    end

    def self.lane_status(open_tasks)
      return "ready" if open_tasks.empty?
      return "blocked" if open_tasks.any?(&:overdue?)

      "in_progress"
    end

    def self.accent_for(owner)
      {
        "benefits" => "bg-cyan-500",
        "payroll" => "bg-indigo-500",
        "people" => "bg-emerald-500"
      }.fetch(owner.to_s, "bg-slate-500")
    end

    private_class_method :lane_status, :accent_for
  end
end
