class EventCalendarDocument
  def initialize(registration=nil,event:nil)
    @registration = registration
    @event=event||registration.event
  end

  def render
    event = @event
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//NishioHub//Events//EN", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
      "BEGIN:VEVENT", "UID:event-#{event.id}@nishiohub.com",
      "DTSTAMP:#{stamp(Time.current)}", "DTSTART:#{stamp(event.starts_at)}", "DTEND:#{stamp(event.ends_at)}",
      "SUMMARY:#{escape(event.title)}", "DESCRIPTION:#{escape(event.description)}", "LOCATION:#{escape(event.location)}"]
    lines << "STATUS:#{event.status == 'cancelled' ? 'CANCELLED' : event.status == 'draft' ? 'TENTATIVE' : 'CONFIRMED'}"
    lines << "SEQUENCE:#{event.lock_version}"
    lines << "URL:#{escape(event.meeting_url)}" if @registration&&event.meeting_url.present?
    if @registration&&@registration.reminder_minutes.positive?
      lines += ["BEGIN:VALARM", "ACTION:DISPLAY", "TRIGGER:-PT#{@registration.reminder_minutes}M",
        "DESCRIPTION:#{escape(event.title)}", "END:VALARM"]
    end
    lines += ["END:VEVENT", "END:VCALENDAR"]
    lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
  end

  private

  def stamp(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def escape(value)
    escapes = { "\\" => "\\\\", "\r\n" => '\\n', "\r" => '\\n', "\n" => '\\n', ";" => '\\;', "," => '\\,' }
    value.to_s.gsub(/\\|\r\n|\r|\n|;|,/) { |character| escapes.fetch(character) }
  end

  def fold(line)
    parts = [""]
    line.each_char do |char|
      parts << " " if parts.last.bytesize + char.bytesize > 75
      parts[-1] += char
    end
    parts.join("\r\n")
  end
end
