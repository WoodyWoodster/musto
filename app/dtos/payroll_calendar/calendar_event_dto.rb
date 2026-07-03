module PayrollCalendar
  CalendarEventDto = Data.define(:key, :title, :detail, :event_at, :status, :owner, :kind)
end
