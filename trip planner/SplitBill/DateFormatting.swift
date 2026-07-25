//
//  DateFormatting.swift
//  trip planner
//
//  Turns API ISO date strings ("2026-08-01") into Indonesian display labels
//  ("1 Agustus 2026").
//

import Foundation

extension Formatters {
    private static let isoParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let idDisplay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    /// "2026-08-01" -> "1 Agustus 2026". Falls back to the raw string if unparseable.
    static func dateLabel(_ iso: String) -> String {
        guard let date = isoParser.date(from: iso) else { return iso }
        return idDisplay.string(from: date)
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
