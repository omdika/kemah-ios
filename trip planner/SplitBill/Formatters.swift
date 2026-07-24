//
//  Formatters.swift
//  trip planner
//
//  Currency + phone helpers ported from the prototype (`rp`, `waLinkFor`).
//

import Foundation

enum Formatters {
    /// Mirrors the prototype's `rp(n)` = "Rp" + n.toLocaleString('id-ID').
    /// id-ID groups thousands with a dot: 150000 -> "Rp150.000".
    static func rp(_ value: Double) -> String {
        let rounded = value.rounded()
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = 0
        let number = NSNumber(value: rounded)
        return "Rp" + (formatter.string(from: number) ?? "\(Int(rounded))")
    }

    /// Mirrors `waLinkFor(phone)`: normalize to international, build wa.me link.
    /// Leading `0` -> `62`; otherwise ensure a `62` prefix. Empty -> nil.
    static func waLink(for phone: String?) -> URL? {
        guard let phone, !phone.isEmpty else { return nil }
        var digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        if digits.hasPrefix("0") {
            digits = "62" + digits.dropFirst()
        } else if !digits.hasPrefix("62") {
            digits = "62" + digits
        }
        return URL(string: "https://wa.me/\(digits)")
    }
}
