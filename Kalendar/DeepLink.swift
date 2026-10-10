//
//  DeepLink.swift
//  Kalendar
//
//  URLs opened from widgets, e.g. kalendar://day?t=1728518400
//

import Foundation

enum DeepLink: Equatable {
    /// Show the given day.
    case day(Date)
    /// Open the event editor on the given day.
    case newEvent(Date)

    private static let scheme = "kalendar"

    init?(url: URL) {
        guard url.scheme == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let timestamp = components.queryItems?.first(where: { $0.name == "t" })?.value.flatMap(TimeInterval.init)
        else { return nil }

        let date = Date(timeIntervalSince1970: timestamp)
        switch components.host {
        case "day": self = .day(date)
        case "new": self = .newEvent(date)
        default: return nil
        }
    }
}
