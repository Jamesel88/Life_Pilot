import Foundation

/// Lightweight natural-language parsing for the quick-add field —
/// "Dentist tomorrow 3pm", "Call mum friday", "Pay rent next month".
/// Deliberately small: day words, weekday names, "next week/month", and
/// clock times. Anything unrecognised stays in the title.
enum QuickAddParser {

    struct Result {
        var title: String
        var dueDate: Date
        var hasTime: Bool
        /// Whether any date/time token was actually recognised
        var matchedDate: Bool
    }

    private static let weekdayNames = ["sunday": 1, "monday": 2, "tuesday": 3,
                                       "wednesday": 4, "thursday": 5,
                                       "friday": 6, "saturday": 7]

    static func parse(_ input: String, now: Date = .now,
                      calendar: Calendar = .current) -> Result {
        let words = input.split(separator: " ").map(String.init)
        var day: Date?
        var time: (hour: Int, minute: Int)?
        var consumed = Set<Int>()

        for (index, rawWord) in words.enumerated() {
            let word = rawWord.lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
            let previous = index > 0
                ? words[index - 1].lowercased()
                    .trimmingCharacters(in: .punctuationCharacters)
                : ""

            switch word {
            case "today":
                day = now
                consumed.insert(index)
            case "tonight":
                day = now
                if time == nil { time = (19, 0) }
                consumed.insert(index)
            case "tomorrow":
                day = calendar.date(byAdding: .day, value: 1, to: now)
                consumed.insert(index)
            case "week" where previous == "next":
                day = calendar.date(byAdding: .weekOfYear, value: 1, to: now)
                consumed.insert(index)
                consumed.insert(index - 1)
            case "month" where previous == "next":
                day = calendar.date(byAdding: .month, value: 1, to: now)
                consumed.insert(index)
                consumed.insert(index - 1)
            default:
                if let weekday = weekdayNames[word] {
                    var date = nextOccurrence(of: weekday, after: now, calendar: calendar)
                    if previous == "next" {
                        date = calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
                        consumed.insert(index - 1)
                    } else if previous == "on" {
                        consumed.insert(index - 1)
                    }
                    day = date
                    consumed.insert(index)
                } else if let parsed = parseTime(word) {
                    time = parsed
                    consumed.insert(index)
                    if previous == "at" {
                        consumed.insert(index - 1)
                    }
                }
            }
        }

        let title = words.enumerated()
            .filter { !consumed.contains($0.offset) }
            .map(\.element)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Time with no day: today — unless that moment already passed,
        // then tomorrow ("dinner 7pm" typed at 9pm means tomorrow's)
        var resolvedDay = day ?? now
        if day == nil, let time,
           let candidate = calendar.date(bySettingHour: time.hour, minute: time.minute,
                                         second: 0, of: now),
           candidate < now {
            resolvedDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        }

        var dueDate = calendar.startOfDay(for: resolvedDay)
        if let time {
            dueDate = calendar.date(bySettingHour: time.hour, minute: time.minute,
                                    second: 0, of: resolvedDay) ?? dueDate
        }

        return Result(title: title.isEmpty ? input : title,
                      dueDate: dueDate,
                      hasTime: time != nil,
                      matchedDate: day != nil || time != nil)
    }

    /// "3pm", "3:30pm", "15:00", "7am" — requires am/pm or a colon so a
    /// bare number like "buy 6 eggs" is never eaten.
    private static func parseTime(_ word: String) -> (hour: Int, minute: Int)? {
        let pattern = /^(\d{1,2})(?::(\d{2}))?(am|pm)?$/
        guard let match = word.wholeMatch(of: pattern) else { return nil }
        guard match.2 != nil || match.3 != nil else { return nil }

        var hour = Int(match.1) ?? 0
        let minute = match.2.flatMap { Int($0) } ?? 0
        guard hour <= 23, minute <= 59 else { return nil }

        if let meridiem = match.3 {
            if meridiem == "pm" && hour < 12 { hour += 12 }
            if meridiem == "am" && hour == 12 { hour = 0 }
        }
        return (hour, minute)
    }

    private static func nextOccurrence(of weekday: Int, after date: Date,
                                       calendar: Calendar) -> Date {
        let today = calendar.component(.weekday, from: date)
        var delta = (weekday - today + 7) % 7
        if delta == 0 { delta = 7 }   // "monday" said on a Monday = next one
        return calendar.date(byAdding: .day, value: delta, to: date) ?? date
    }
}
