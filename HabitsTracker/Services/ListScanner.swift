import Foundation
import UIKit
import Vision

/// Turns a photo of a written list into proposed tasks: on-device Vision
/// OCR extracts the lines, then each line goes through the quick-add
/// parser (tomorrow, friday, 3pm) plus explicit-date recognition (20/7,
/// 3rd Aug, Aug 3). Lines with no date default to today.
enum ListScanner {

    struct ScannedTask: Identifiable {
        let id = UUID()
        var title: String
        var dueDate: Date
        var hasTime: Bool
        var matchedDate: Bool
        var isIncluded: Bool = true
    }

    enum ScanError: LocalizedError {
        case noText

        var errorDescription: String? {
            "Couldn't find any readable text in that photo. Try a sharper, straight-on shot."
        }
    }

    // MARK: - OCR

    /// Recognise text lines in the photo, top to bottom.
    static func recognizeLines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ScanError.noText }
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            // Vision's coordinate origin is bottom-left, so higher midY = higher on the page
            let lines = (request.results ?? [])
                .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                .compactMap { $0.topCandidates(1).first?.string }
            guard !lines.isEmpty else { throw ScanError.noText }
            return lines
        }.value
    }

    // MARK: - Line → task

    static func proposedTasks(from lines: [String], now: Date = .now,
                              calendar: Calendar = .current) -> [ScannedTask] {
        lines.compactMap { line in
            let stripped = stripListDecoration(line)
            guard stripped.count >= 2 else { return nil }

            // Word tokens first (tomorrow, friday, 3pm)…
            let parsed = QuickAddParser.parse(stripped, now: now, calendar: calendar)
            var title = parsed.title
            var dueDate = parsed.dueDate
            var matchedDate = parsed.matchedDate

            // …then written dates (20/7, 20-07-2026, 3rd Aug, Aug 3)
            if let explicit = extractExplicitDate(from: title, now: now, calendar: calendar) {
                title = explicit.remainingTitle
                matchedDate = true
                if parsed.hasTime {
                    let time = calendar.dateComponents([.hour, .minute], from: parsed.dueDate)
                    dueDate = calendar.date(bySettingHour: time.hour ?? 9,
                                            minute: time.minute ?? 0, second: 0,
                                            of: explicit.date) ?? explicit.date
                } else {
                    dueDate = calendar.startOfDay(for: explicit.date)
                }
            }

            guard !title.isEmpty else { return nil }
            return ScannedTask(title: title, dueDate: dueDate,
                               hasTime: parsed.hasTime, matchedDate: matchedDate)
        }
    }

    /// Remove bullets, checkboxes, and "1." / "2)" numbering.
    private static func stripListDecoration(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        text = text.replacing(/^[\-–—•*◦▪☐☑✓\[\]\s]+/, with: "")
        text = text.replacing(/^\d{1,2}[\.\)]\s+/, with: "")
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Explicit dates

    private static let monthNames = ["january", "february", "march", "april",
                                     "may", "june", "july", "august",
                                     "september", "october", "november", "december"]

    private static func monthNumber(_ word: String) -> Int? {
        let lowered = word.lowercased()
        guard lowered.count >= 3 else { return nil }
        return monthNames.firstIndex { $0.hasPrefix(lowered) }.map { $0 + 1 }
    }

    private static func extractExplicitDate(from title: String, now: Date,
                                            calendar: Calendar)
        -> (date: Date, remainingTitle: String)? {

        // 20/7, 20-7, 20.07.2026 (day first)
        if let match = title.firstMatch(of: /\b(\d{1,2})[\/\-\.](\d{1,2})(?:[\/\-\.](\d{2,4}))?\b/) {
            var year = match.3.flatMap { Int($0) }
            if let value = year, value < 100 { year = 2000 + value }
            if let date = makeDate(day: Int(match.1) ?? 0, month: Int(match.2) ?? 0,
                                   year: year, now: now, calendar: calendar) {
                return (date, removing(match.range, from: title))
            }
        }

        // 3 Aug, 3rd August
        if let match = title.firstMatch(of: /\b(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\b/),
           let month = monthNumber(String(match.2)),
           let date = makeDate(day: Int(match.1) ?? 0, month: month,
                               year: nil, now: now, calendar: calendar) {
            return (date, removing(match.range, from: title))
        }

        // Aug 3, August 3rd
        if let match = title.firstMatch(of: /\b([A-Za-z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?\b/),
           let month = monthNumber(String(match.1)),
           let date = makeDate(day: Int(match.2) ?? 0, month: month,
                               year: nil, now: now, calendar: calendar) {
            return (date, removing(match.range, from: title))
        }

        return nil
    }

    private static func makeDate(day: Int, month: Int, year: Int?,
                                 now: Date, calendar: Calendar) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year ?? calendar.component(.year, from: now)
        guard let date = calendar.date(from: components) else { return nil }
        // A yearless date that's already passed almost certainly means next year
        if year == nil, date < calendar.startOfDay(for: now),
           let nextYear = calendar.date(byAdding: .year, value: 1, to: date) {
            return nextYear
        }
        return date
    }

    private static func removing(_ range: Range<String.Index>, from title: String) -> String {
        var remaining = title
        remaining.removeSubrange(range)
        return remaining
            .replacing(/\s{2,}/, with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t-–—:,•"))
    }
}
