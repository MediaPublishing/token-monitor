import Foundation

public struct BankedResetGroup: Codable, Equatable, Identifiable, Sendable {
    public let title: String
    public let expiresAt: Date?
    public let expiryText: String
    public var count: Int

    public var id: String { "\(title)|\(expiresAt.map { String($0.timeIntervalSince1970) } ?? expiryText)" }

    public init(title: String, expiresAt: Date?, expiryText: String, count: Int = 1) {
        self.title = title
        self.expiresAt = expiresAt
        self.expiryText = expiryText
        self.count = count
    }
}

public struct BankedResetInventory: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let groups: [BankedResetGroup]

    public init(capturedAt: Date, groups: [BankedResetGroup]) {
        self.capturedAt = capturedAt
        self.groups = groups
    }

    public func availableGroups(at now: Date) -> [BankedResetGroup] {
        groups.filter { $0.count > 0 && ($0.expiresAt.map { $0 > now } ?? true) }
    }

    public func availableCount(at now: Date) -> Int {
        availableGroups(at: now).reduce(0) { $0 + $1.count }
    }
}

public enum BankedResetParser {
    public static func isLoading(_ extract: ServicePageExtract) -> Bool {
        guard let text = section(from: extract) else { return false }
        return text.range(of: #"loading|wird geladen|werden geladen|laden\.\.\."#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    public static func parse(_ extract: ServicePageExtract, now: Date) -> BankedResetInventory? {
        guard extract.service == .chatGPT, let text = section(from: extract), !isLoading(extract) else { return nil }
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var groups: [BankedResetGroup] = []
        let timeZone = extract.pageTimeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        for (index, line) in lines.enumerated() {
            guard let title = resetTitle(line) else { continue }
            // Only the expiry belonging to this card may be used, never a plan reset.
            let tail = lines.dropFirst(index + 1).prefix(3).prefix { resetTitle($0) == nil }
            guard let expiry = tail.first(where: { $0.range(of: #"^(Expires|Verfällt|Ablauf|Gültig bis)\b"#, options: [.regularExpression, .caseInsensitive]) != nil }) else {
                return nil
            }
            let group = BankedResetGroup(title: title, expiresAt: expiryDate(expiry, now: now, timeZone: timeZone), expiryText: expiry)
            if let existing = groups.firstIndex(where: { $0.id == group.id }) {
                groups[existing].count += 1
            } else {
                groups.append(group)
            }
        }
        if groups.isEmpty {
            let emptyPattern = #"\bno (?:banked |usage limit )?resets(?: available)?\b|\b0 (?:banked |usage limit )?resets\b|keine .*resets|keine .*zurücksetzungen"#
            guard text.range(of: emptyPattern, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        }
        return BankedResetInventory(capturedAt: now, groups: groups)
    }

    private static func resetTitle(_ line: String) -> String? {
        switch line.lowercased() {
        case "full reset", "vollständiger reset", "vollständige zurücksetzung": return "Full reset"
        case "5-hour reset", "5 hour reset", "5-stunden-reset": return "5-hour reset"
        case "weekly reset", "wöchentlicher reset": return "Weekly reset"
        default: return nil
        }
    }

    private static func section(from extract: ServicePageExtract) -> String? {
        if let text = extract.bankedResetText { return text }
        // Older extracts include overlapping DOM segments. Parse one section, not
        // their concatenation, so the same reset is never counted several times.
        let candidates = [extract.bodyText] + extract.segments.sorted { $0.count > $1.count }
        let heading = #"(?:Usage limit resets|Banked resets|Gespeicherte Resets|Nutzungslimit-Zurücksetzungen)"#
        for candidate in candidates {
            guard let start = candidate.range(of: heading, options: [.regularExpression, .caseInsensitive]) else { continue }
            var section = String(candidate[start.upperBound...])
            let end = #"(?:Auto reload|Auto-reload credits|Usage breakdown|Credits usage history|Usage limit resets|Banked resets)"#
            if let boundary = section.range(of: end, options: [.regularExpression, .caseInsensitive]) {
                section = String(section[..<boundary.lowerBound])
            }
            if !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return section }
        }
        return nil
    }

    static func expiryDate(_ text: String, now: Date, timeZone: TimeZone) -> Date? {
        let value = text.replacingOccurrences(of: #"^(?:Expires|Verfällt(?: am)?|Ablauf:?|Gültig bis)\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\u{202f}", with: " ").replacingOccurrences(of: "\u{00a0}", with: " ")
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let year = calendar.component(.year, from: now)
        let hasYear = value.range(of: #"\b20\d{2}\b"#, options: .regularExpression) != nil
        let formats: [(String, String)] = [
            ("en_US_POSIX", "MMM d 'at' h:mm a"), ("en_US_POSIX", "MMM d 'at' HH:mm"),
            ("en_US_POSIX", "MMM d h:mm a"), ("en_US_POSIX", "MMM d HH:mm"),
            ("en_US_POSIX", "MMM d, yyyy 'at' h:mm a"), ("en_US_POSIX", "MMM d, yyyy HH:mm"),
            ("de_DE", "d. MMM 'um' HH:mm"), ("de_DE", "d. MMM HH:mm"),
            ("en_US_POSIX", "d. MMM. 'um' HH:mm"),
            ("de_DE", "dd.MM.yyyy HH:mm")
        ]
        for (locale, format) in formats where format.contains("yyyy") == hasYear {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: locale)
            formatter.timeZone = timeZone
            formatter.isLenient = false
            formatter.dateFormat = hasYear ? format : format + " yyyy"
            guard var date = formatter.date(from: hasYear ? value : value + " \(year)") else { continue }
            // Only roll a yearless January/February date across a real year boundary.
            if !hasYear, calendar.component(.month, from: now) >= 11,
               calendar.component(.month, from: date) <= 2 {
                date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
            }
            return date
        }
        return nil
    }
}

public struct ResetReminder: Equatable, Sendable {
    public let identifier: String
    public let count: Int
    public let expiresAt: Date
    public let fireAt: Date
}

public enum ResetReminderPlanner {
    public static let identifierPrefix = "banked-reset-expiry-"
    public static let leadTime: TimeInterval = 72 * 60 * 60

    public static func reminders(for inventory: BankedResetInventory, now: Date) -> [ResetReminder] {
        let dated = inventory.availableGroups(at: now).filter { $0.expiresAt != nil }
        return Dictionary(grouping: dated, by: { $0.expiresAt! }).map { expiry, groups in
            ResetReminder(
                identifier: identifierPrefix + String(Int(expiry.timeIntervalSince1970)),
                count: groups.reduce(0) { $0 + $1.count },
                expiresAt: expiry,
                fireAt: max(expiry.addingTimeInterval(-leadTime), now.addingTimeInterval(1))
            )
        }.sorted { $0.expiresAt < $1.expiresAt }
    }

    public static func shouldSchedule(_ reminder: ResetReminder, previousFireDate: Date?, delivered: Bool, now: Date) -> Bool {
        if delivered { return false }
        // A scheduled reminder that has become due must not be recreated on each refresh/restart.
        if let previousFireDate, previousFireDate <= now { return false }
        return true
    }
}
