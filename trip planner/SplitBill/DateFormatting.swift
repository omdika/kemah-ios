//
//  DateFormatting.swift
//  trip planner
//
//  Turns API ISO date strings ("2026-08-01") into Indonesian display labels
//  ("1 Agustus 2026").
//

import Foundation

extension Formatters {
    /// Date-only ISO strings ("2026-08-01") represent a calendar date, not an
    /// instant — always parse/format them in UTC so the day doesn't drift
    /// depending on the device's local timezone (e.g. midnight-local in a
    /// negative-offset zone parses to the previous UTC day).
    private static let isoParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let idDisplay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    /// "2026-08-01" -> "1 Agustus 2026". Falls back to the raw string if unparseable.
    static func dateLabel(_ iso: String) -> String {
        guard let date = isoParser.date(from: iso) else { return iso }
        return idDisplay.string(from: date)
    }

    /// "2026-08-01" -> Date at UTC midnight, for pre-filling a DatePicker from
    /// an API date string. nil if unparseable.
    static func date(fromISODate iso: String) -> Date? {
        isoParser.date(from: iso)
    }

    /// Inverse of `date(fromISODate:)` — Date -> "2026-08-01" in UTC, so the
    /// round trip through a DatePicker can't drift a day on the way back out.
    static func isoDateString(from date: Date) -> String {
        isoParser.string(from: date)
    }

    private static let isoTimestampParser = ISO8601DateFormatter()

    private static let idDisplayWithTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM yyyy, HH:mm"
        return f
    }()

    /// "2026-07-21T10:00:00Z" -> "21 Jul 2026, 10:00". Falls back to the raw string if unparseable.
    static func dateTimeLabel(_ iso: String) -> String {
        guard let date = isoTimestampParser.date(from: iso) else { return iso }
        return idDisplayWithTime.string(from: date)
    }
}
