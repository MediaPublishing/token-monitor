import Foundation

public protocol UsageParsing: Sendable {
    func parse(extract: ServicePageExtract, now: Date) throws -> ServiceSnapshot
}

public struct ClaudeUsageParser: UsageParsing {
    public init() {}

    public func parse(extract: ServicePageExtract, now: Date) throws -> ServiceSnapshot {
        if extractLooksLikeLogin(extract, keywords: [
            "log in to claude",
            "continue with google",
            "continue with email",
            "verify you're human",
            "verify you are human"
        ]) {
            throw UsageParseError.authRequired(ServiceKind.claude.loginRequiredMessage)
        }

        let lines = claudeCandidateLines(from: extract)
        let monthlyLimitLabels = ["Monthly spend limit", "Monthly limit", "Monatliches Ausgabenlimit", "Monatliches Limit"]
        let balanceLabels = ["Current balance", "Balance", "Aktueller Kontostand", "Aktuelles Guthaben"]
        guard
            let currentSessionIndex = firstIndex(in: lines, containingAny: ["Current session", "Aktuelle Sitzung", "Sitzung"]),
            let allModelsIndex = firstIndex(in: lines, containingAny: ["All models", "Alle Modelle"]),
            let currentSessionValue = firstLine(after: currentSessionIndex, in: lines, matching: isUsageUsedValue),
            let allModelsValue = firstLine(after: allModelsIndex, in: lines, matching: isUsageUsedValue),
            let allModelsReset = firstLine(after: allModelsIndex, in: lines, matching: isResetLine)
        else {
            throw UsageParseError.unsupportedLayout("Claude usage layout could not be parsed")
        }

        var metrics = [
            UsageMetric(
                key: "current-session",
                title: "Current session",
                valueText: remainingProgressText(fromUsedText: currentSessionValue),
                subtitle: firstLine(after: currentSessionIndex, in: lines, matching: { $0 != currentSessionValue }),
                progress: remainingProgress(fromUsedText: currentSessionValue),
                style: .progress
            ),
            UsageMetric(
                key: "weekly-all-models",
                title: "All models",
                valueText: remainingProgressText(fromUsedText: allModelsValue),
                subtitle: allModelsReset,
                progress: remainingProgress(fromUsedText: allModelsValue),
                style: .progress
            )
        ]

        if let sonnetMetric = optionalClaudeUsageMetric(
            key: "weekly-sonnet",
            title: "Sonnet only",
            lines: lines,
            labels: ["Sonnet only", "Nur Sonnet", "Sonnet"]
        ) {
            metrics.insert(sonnetMetric, at: 2)
        }

        if let claudeDesignMetric = optionalClaudeUsageMetric(
            key: "claude-design",
            title: "Claude Design",
            lines: lines,
            labels: ["Claude Design"]
        ) {
            let insertIndex = metrics.firstIndex { $0.key == "extra-usage-spend" } ?? metrics.endIndex
            metrics.insert(claudeDesignMetric, at: insertIndex)
        }

        if let fableMetric = optionalClaudeUsageMetric(
            key: "weekly-fable",
            title: "Fable",
            lines: lines,
            labels: ["Fable"],
            requiresExactLabel: true
        ) {
            metrics.append(fableMetric)
        }

        if let extraUsageIndex = firstIndex(
            in: lines,
            containingAny: ["Extra usage", "Usage credits", "Zusätzliche Nutzung", "Zusätzliche Verwendung", "Nutzungsguthaben"]
        ),
           let extraUsageSpent = firstLine(after: extraUsageIndex, in: lines, matching: isSpentLine),
           let extraUsageReset = firstLine(after: extraUsageIndex, in: lines, matching: isResetLine),
           let extraUsagePercent = firstLine(after: extraUsageIndex, in: lines, matching: isUsageUsedValue) {
            metrics.append(
                UsageMetric(
                    key: "extra-usage-spend",
                    title: "Extra usage",
                    valueText: extraUsageSpent,
                    subtitle: extraUsageReset,
                    progress: percentage(from: extraUsagePercent),
                    style: .progress
                )
            )
        }

        let monthlyLimitIndex = firstIndex(in: lines, containingAny: monthlyLimitLabels)
        let balanceIndex = firstIndex(in: lines, containingAny: balanceLabels)
            ?? firstIndex(in: lines, exactlyMatchingAny: ["Guthaben"])

        if let monthlyLimitIndex,
           let monthlyLimitValue = claudeMoneyValue(
               near: monthlyLimitIndex,
               in: lines,
               occurrence: monthlyLimitIndex == balanceIndex ? 0 : nil
           ),
           isClaudeMoneyValue(monthlyLimitValue) {
            metrics.append(
                UsageMetric(
                    key: "monthly-spend-limit",
                    title: "Monthly spend limit",
                    valueText: monthlyLimitValue,
                    subtitle: nil,
                    progress: nil,
                    style: .stat
                )
            )
        }

        if let balanceIndex,
           let currentBalanceValue = claudeMoneyValue(
               near: balanceIndex,
               in: lines,
               occurrence: monthlyLimitIndex == balanceIndex ? 1 : nil
           ),
           isClaudeMoneyValue(currentBalanceValue) {
            metrics.append(
                UsageMetric(
                    key: "current-balance",
                    title: "Current balance",
                    valueText: currentBalanceValue,
                    subtitle: nil,
                    progress: nil,
                    style: .stat
                )
            )
        }

        return ServiceSnapshot(
            service: .claude,
            capturedAt: now,
            pageTitle: extract.pageTitle,
            url: extract.url,
            metrics: metrics
        )
    }
}

public struct ChatGPTUsageParser: UsageParsing {
    public init() {}

    public func parse(extract: ServicePageExtract, now: Date) throws -> ServiceSnapshot {
        if extractLooksLikeLogin(extract, keywords: [
            "log in",
            "sign in",
            "continue with google",
            "continue with apple",
            "melde dich an",
            "anmelden",
            "mit google fortfahren",
            "mit apple fortfahren",
            "kostenlos registrieren",
            "verify you are human",
            "verify you're human"
        ]) {
            throw UsageParseError.authRequired(ServiceKind.chatGPT.loginRequiredMessage)
        }

        let specs: [ChatGPTMetricSpec] = [
            .init(key: "five-hour-limit", kind: .progress, match: { line in
                isUsageLimitTitle(line, duration: .fiveHour, requiresModelName: false)
            }),
            .init(key: "weekly-limit", kind: .progress, match: { line in
                isUsageLimitTitle(line, duration: .weekly, requiresModelName: false)
            }),
            .init(key: "spark-five-hour-limit", kind: .progress, match: { line in
                isUsageLimitTitle(line, duration: .fiveHour, requiresModelName: true)
            }),
            .init(key: "spark-weekly-limit", kind: .progress, match: { line in
                isUsageLimitTitle(line, duration: .weekly, requiresModelName: true)
            }),
            .init(key: "credits-remaining", kind: .stat, match: { line in
                line.localizedCaseInsensitiveContains("credits remaining")
                    || line.localizedCaseInsensitiveContains("verbleibendes guthaben")
                    || line.localizedCaseInsensitiveContains("guthaben verbleibend")
            })
        ]

        var metricsByKey: [String: UsageMetric] = [:]

        for cardLines in extract.segments.map({ normalizedLines(from: $0) }).filter({ !$0.isEmpty }) {
            guard let metric = parseChatGPTMetricCard(from: cardLines, specs: specs) else {
                continue
            }
            if shouldReplaceChatGPTMetric(metricsByKey[metric.key], with: metric) {
                metricsByKey[metric.key] = metric
            }
        }

        let lines = chatGPTCandidateLines(from: extract)
        for spec in specs where metricsByKey[spec.key] == nil {
            guard let titleIndex = lines.firstIndex(where: spec.match) else {
                continue
            }

            let title = lines[titleIndex]
            guard let valueText = try? extractChatGPTValue(after: titleIndex, lines: lines, kind: spec.kind) else {
                continue
            }
            let subtitle = extractChatGPTSubtitle(after: titleIndex, lines: lines, valueText: valueText, kind: spec.kind)

            metricsByKey[spec.key] = UsageMetric(
                key: spec.key,
                title: title,
                valueText: valueText,
                subtitle: subtitle,
                progress: spec.kind == .progress ? percentage(from: valueText) : nil,
                style: spec.kind
            )
        }

        let metrics = specs.compactMap { metricsByKey[$0.key] }
        let progressMetricCount = metrics.filter { $0.style == .progress }.count
        guard progressMetricCount >= 1 else {
            throw UsageParseError.unsupportedLayout("ChatGPT usage layout could not be parsed")
        }

        guard !metrics.isEmpty else {
            throw UsageParseError.unsupportedLayout("ChatGPT usage layout could not be parsed")
        }

        return ServiceSnapshot(
            service: .chatGPT,
            capturedAt: now,
            pageTitle: extract.pageTitle,
            url: extract.url,
            metrics: metrics
        )
    }
}

public struct OpenCodeGoUsageParser: UsageParsing {
    public init() {}

    public func parse(extract: ServicePageExtract, now: Date) throws -> ServiceSnapshot {
        if extractLooksLikeLogin(extract, keywords: [
            "sign in",
            "log in",
            "login",
            "anmelden",
            "einloggen",
            "continue with google",
            "continue with github",
            "create an account",
            "konto erstellen",
            "/auth"
        ]) {
            throw UsageParseError.authRequired(ServiceKind.openCodeGo.loginRequiredMessage)
        }

        let specs = [
            OpenCodeGoMetricSpec(
                key: "rolling-usage",
                title: "5 hour",
                labels: [
                    "5-hour Usage",
                    "5 hour Usage",
                    "Rolling Usage",
                    "5-Stunden-Nutzung",
                    "5 Stunden Nutzung",
                    "Fortlaufende Nutzung"
                ]
            ),
            OpenCodeGoMetricSpec(
                key: "weekly-usage",
                title: "Weekly Usage",
                labels: ["Weekly Usage", "Wöchentliche Nutzung"]
            ),
            OpenCodeGoMetricSpec(
                key: "monthly-usage",
                title: "Monthly Usage",
                labels: ["Monthly Usage", "Monatliche Nutzung"]
            )
        ]
        let labels = specs.flatMap(\.labels)
        let lines = openCodeCandidateLines(from: extract, splittingAt: labels)
        let metrics = specs.compactMap { parseOpenCodeGoMetric($0, from: lines, stoppingAt: labels) }

        guard !metrics.isEmpty else {
            throw UsageParseError.unsupportedLayout("OpenCode Go usage layout could not be parsed")
        }

        return ServiceSnapshot(
            service: .openCodeGo,
            capturedAt: now,
            pageTitle: extract.pageTitle,
            url: extract.url,
            metrics: metrics
        )
    }
}

private struct OpenCodeGoMetricSpec {
    let key: String
    let title: String
    let labels: [String]
}

private func parseOpenCodeGoMetric(
    _ spec: OpenCodeGoMetricSpec,
    from lines: [String],
    stoppingAt labels: [String]
) -> UsageMetric? {
    guard let titleIndex = firstIndex(in: lines, containingAny: spec.labels) else {
        return nil
    }

    let nextTitleIndex = firstIndex(after: titleIndex, in: lines, containingAny: labels)
    let searchEndIndex = min(nextTitleIndex ?? lines.endIndex, titleIndex + 5)
    let value: String?
    if let valueOnTitle = normalizedOpenCodeGoPercentage(lines[titleIndex]) {
        value = valueOnTitle
    } else if titleIndex + 1 < searchEndIndex {
        value = lines[(titleIndex + 1)..<searchEndIndex].compactMap(normalizedOpenCodeGoPercentage).first
    } else {
        value = nil
    }
    guard let value,
          let rawProgress = percentage(from: value) else {
        return nil
    }

    let progress = value.localizedCaseInsensitiveContains("remaining")
        ? rawProgress
        : max(0, min(1, 1 - rawProgress))
    let remainingText = "\(Int((progress * 100).rounded()))% remaining"

    return UsageMetric(
        key: spec.key,
        title: spec.title,
        valueText: remainingText,
        subtitle: nearbyOpenCodeGoLine(
            after: titleIndex,
            before: searchEndIndex,
            in: lines,
            matching: isResetLine
        ),
        progress: progress,
        style: .progress
    )
}

private func nearbyOpenCodeGoLine(
    after index: Int,
    before endIndex: Int,
    in lines: [String],
    matching predicate: (String) -> Bool
) -> String? {
    guard index + 1 < endIndex else {
        return nil
    }

    return lines[(index + 1)..<endIndex].first(where: predicate)
}

private struct ChatGPTMetricSpec {
    let key: String
    let kind: UsageMetricStyle
    let match: (String) -> Bool
}

private func parseChatGPTMetricCard(from lines: [String], specs: [ChatGPTMetricSpec]) -> UsageMetric? {
    guard let titleIndex = lines.indices.first(where: { index in
        specs.contains(where: { $0.match(lines[index]) })
    }) else {
        return nil
    }

    let title = lines[titleIndex]
    guard let spec = specs.first(where: { $0.match(title) }) else {
        return nil
    }
    guard let valueText = try? extractChatGPTValue(after: titleIndex, lines: lines, kind: spec.kind) else {
        return nil
    }

    return UsageMetric(
        key: spec.key,
        title: title,
        valueText: valueText,
        subtitle: extractChatGPTSubtitle(after: titleIndex, lines: lines, valueText: valueText, kind: spec.kind),
        progress: spec.kind == .progress ? percentage(from: valueText) : nil,
        style: spec.kind
    )
}

private func shouldReplaceChatGPTMetric(_ existing: UsageMetric?, with candidate: UsageMetric) -> Bool {
    guard let existing else {
        return true
    }

    if existing.subtitle == nil, candidate.subtitle != nil {
        return true
    }

    return false
}

private enum ChatGPTDuration {
    case fiveHour
    case weekly
}

private func isUsageLimitTitle(_ line: String, duration: ChatGPTDuration, requiresModelName: Bool) -> Bool {
    guard line.count <= 180 else {
        return false
    }

    let normalized = line
        .lowercased()
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "  ", with: " ")

    guard normalized.contains("limit") else {
        return false
    }

    let hasDuration: Bool
    switch duration {
    case .fiveHour:
        hasDuration = normalized.contains("5 hour") || normalized.contains("5 stunden")
    case .weekly:
        hasDuration = normalized.contains("weekly")
            || normalized.contains("wöchentlich")
            || normalized.contains("woechentlich")
    }

    guard hasDuration else {
        return false
    }

    let hasModelName = normalized.contains("gpt") || normalized.contains("codex") || normalized.contains("spark")

    return requiresModelName ? hasModelName : !hasModelName
}

private func extractChatGPTValue(after index: Int, lines: [String], kind: UsageMetricStyle) throws -> String {
    let upperBound = min(lines.count - 1, index + 8)
    guard index + 1 <= upperBound else {
        throw UsageParseError.unsupportedLayout("ChatGPT usage layout could not be parsed")
    }

    for candidateIndex in (index + 1)...upperBound {
        let candidate = lines[candidateIndex]

        switch kind {
        case .progress:
            if let progressValue = normalizedProgressValue(candidate) {
                return progressValue
            }

            if candidateIndex < upperBound {
                let combined = "\(candidate) \(lines[candidateIndex + 1])"
                if let progressValue = normalizedProgressValue(combined) {
                    return progressValue
                }
            }

        case .stat:
            if let statValue = normalizedStatValue(candidate) {
                return statValue
            }
        }
    }

    throw UsageParseError.unsupportedLayout("ChatGPT usage layout could not be parsed")
}

private func extractChatGPTSubtitle(after index: Int, lines: [String], valueText: String, kind: UsageMetricStyle) -> String? {
    let upperBound = min(lines.count - 1, index + 8)
    guard index + 1 <= upperBound else {
        return nil
    }

    for candidateIndex in (index + 1)...upperBound {
        let candidate = lines[candidateIndex]

        if candidate == valueText {
            continue
        }

        switch kind {
        case .progress:
            if isResetLine(candidate) {
                return candidate
            }
            if candidate.localizedCaseInsensitiveContains("reset"), candidateIndex < upperBound {
                return "\(candidate) \(lines[candidateIndex + 1])"
            }

        case .stat:
            if normalizedStatValue(candidate) == nil {
                return candidate
            }
        }
    }

    return nil
}

private func extractLooksLikeLogin(_ extract: ServicePageExtract, keywords: [String]) -> Bool {
    let haystack = [extract.pageTitle, extract.bodyText, extract.url]
        .joined(separator: "\n")
        .lowercased()

    return keywords.contains(where: { haystack.contains($0) })
}

private func normalizedLines(from bodyText: String) -> [String] {
    bodyText
        .replacingOccurrences(of: "\r\n", with: "\n")
        .split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func chatGPTCandidateLines(from extract: ServicePageExtract) -> [String] {
    let bodyLines = normalizedLines(from: extract.bodyText)
    var result = bodyLines
    var seen = Set(bodyLines)

    for segment in extract.segments {
        for line in normalizedLines(from: segment) {
            if seen.insert(line).inserted {
                result.append(line)
            }
        }
    }

    return result
}

private func openCodeCandidateLines(from extract: ServicePageExtract, splittingAt labels: [String]) -> [String] {
    var result = normalizedLines(from: extract.bodyText).flatMap { line in
        splitOpenCodeGoLine(line, labels: labels)
    }
    var seen = Set(result)

    for segment in extract.segments {
        for line in normalizedLines(from: segment) {
            for candidate in splitOpenCodeGoLine(line, labels: labels) where seen.insert(candidate).inserted {
                result.append(candidate)
            }
        }
    }

    return result
}

private func splitOpenCodeGoLine(_ line: String, labels: [String]) -> [String] {
    let ranges = labels.compactMap { label in
        line.range(of: label, options: [.caseInsensitive, .diacriticInsensitive])
    }
    .sorted { $0.lowerBound < $1.lowerBound }

    guard ranges.count > 1 else {
        return [line]
    }

    return ranges.enumerated().map { index, range in
        let end = index + 1 < ranges.count ? ranges[index + 1].lowerBound : line.endIndex
        return String(line[range.lowerBound..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func claudeCandidateLines(from extract: ServicePageExtract) -> [String] {
    let bodyLines = normalizedLines(from: extract.bodyText)
    var result: [String] = []

    for segment in extract.segments {
        result.append(contentsOf: normalizedLines(from: segment))
    }

    // Separate limits can have identical percentages or reset times.
    // Deduplicating individual lines removes values from later sections.
    for line in bodyLines where !looksLikeCollapsedClaudeBodyLine(line) {
        result.append(line)
    }

    return result.isEmpty ? bodyLines : result
}

private func looksLikeCollapsedClaudeBodyLine(_ line: String) -> Bool {
    let markers = [
        "Current session",
        "All models",
        "Sonnet only",
        "Extra usage",
        "Monthly spend limit",
        "Current balance",
        "Aktuelle Sitzung",
        "Alle Modelle",
        "Zusätzliche Nutzung",
        "Monatliches Ausgabenlimit",
        "Aktueller Kontostand",
        "Guthaben"
    ]

    let markerCount = markers.filter { line.localizedCaseInsensitiveContains($0) }.count
    return line.count > 240 && markerCount >= 3
}

private func isClaudeMoneyValue(_ text: String) -> Bool {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let patterns = [
        #"^\$\s?\d+(?:[.,]\d+)?$"#,
        #"^€\s?\d+(?:[.,]\d+)?$"#,
        #"^\d+(?:[.,]\d+)?\s?€$"#,
        #"^\d+(?:[.,]\d+)?$"#
    ]
    return patterns.contains { pattern in
        normalized.range(of: pattern, options: .regularExpression) != nil
    }
}

private func claudeMoneyValue(near index: Int, in lines: [String], occurrence: Int?) -> String? {
    let candidateIndexes = [
        index - 1,
        index,
        index + 1,
        index + 2
    ].filter(lines.indices.contains)

    let values = candidateIndexes.flatMap { claudeMoneyValues(in: lines[$0]) }

    if let occurrence, values.indices.contains(occurrence) {
        return values[occurrence]
    }

    return values.first
}

private func claudeMoneyValues(in text: String) -> [String] {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

    if isClaudeMoneyValue(normalized) {
        return [normalized]
    }

    let separatedValues = normalized
        .split(separator: "/")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter(isClaudeMoneyValue)
    if !separatedValues.isEmpty {
        return separatedValues
    }

    guard let regex = try? NSRegularExpression(pattern: #"(?:[$€]\s?\d+(?:[.,]\d+)?|\d+(?:[.,]\d+)?\s?€)"#) else {
        return []
    }

    let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
    return regex.matches(in: normalized, options: [], range: range).compactMap { match in
        Range(match.range, in: normalized).map { String(normalized[$0]) }
    }
}

private func isUsageUsedValue(_ text: String) -> Bool {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let patterns = [
        #"\d+(?:[.,]\d+)?\s*%\s*used"#,
        #"\d+(?:[.,]\d+)?\s*%\s*(genutzt|verwendet|verbraucht)"#
    ]
    return patterns.contains { pattern in
        normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

private func isResetLine(_ text: String) -> Bool {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.localizedCaseInsensitiveContains("Resets")
        || normalized.localizedCaseInsensitiveContains("Reset")
        || normalized.localizedCaseInsensitiveContains("Zurücksetzung")
        || normalized.localizedCaseInsensitiveContains("Zurücksetzen")
        || normalized.localizedCaseInsensitiveContains("zurückgesetzt")
        || normalized.localizedCaseInsensitiveContains("Setzt zurück")
}

private func isSpentLine(_ text: String) -> Bool {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let containsSpentLabel = normalized.localizedCaseInsensitiveContains("spent")
        || normalized.localizedCaseInsensitiveContains("ausgegeben")
        || normalized.localizedCaseInsensitiveContains("verbraucht")
        || normalized.localizedCaseInsensitiveContains("verwendet")
    return containsSpentLabel && !claudeMoneyValues(in: normalized).isEmpty
}

private func optionalClaudeUsageMetric(
    key: String,
    title: String,
    lines: [String],
    labels: [String],
    requiresExactLabel: Bool = false
) -> UsageMetric? {
    let titleIndex = requiresExactLabel
        ? firstIndex(in: lines, exactlyMatchingAny: labels)
        : firstIndex(in: lines, containingAny: labels)

    guard let titleIndex,
          let value = firstLine(after: titleIndex, in: lines, matching: isUsageUsedValue) else {
        return nil
    }

    return UsageMetric(
        key: key,
        title: title,
        valueText: remainingProgressText(fromUsedText: value),
        subtitle: firstLine(after: titleIndex, in: lines, matching: isResetLine),
        progress: remainingProgress(fromUsedText: value),
        style: .progress
    )
}

private func normalizedProgressValue(_ text: String) -> String? {
    let normalized = text
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let patterns = [
        #"(\d+(?:[.,]\d+)?)\s*%\s*(remaining|used|verbleibend|übrig|genutzt|verwendet|verbraucht)"#,
        #"(\d+(?:[.,]\d+)?)\s*(remaining|used|verbleibend|übrig|genutzt|verwendet|verbraucht)"#
    ]

    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            continue
        }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = regex.firstMatch(in: normalized, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: normalized),
              let statusRange = Range(match.range(at: 2), in: normalized) else {
            continue
        }

        let value = normalized[valueRange]
        let status = normalized[statusRange].lowercased()
        let remainingStatuses = ["remaining", "verbleibend", "übrig"]
        return "\(value)% \(remainingStatuses.contains(status) ? "remaining" : "used")"
    }

    return nil
}

private func normalizedOpenCodeGoPercentage(_ text: String) -> String? {
    let normalized = text
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let range = normalized.range(
        of: #"(\d+(?:[.,]\d+)?)\s*%"#,
        options: .regularExpression
    ) else {
        return nil
    }

    let value = normalized[range]
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ",", with: ".")

    if normalized.localizedCaseInsensitiveContains("remaining") {
        return "\(value) remaining"
    }

    return "\(value) used"
}

private func normalizedStatValue(_ text: String) -> String? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

    guard normalized.range(of: #"^\$?\d+(?:[.,]\d+)?$"#, options: .regularExpression) != nil else {
        return nil
    }

    return normalized.replacingOccurrences(of: "$", with: "")
}

private func firstIndex(in lines: [String], containing needle: String) -> Int? {
    lines.firstIndex { $0.localizedCaseInsensitiveContains(needle) }
}

private func firstIndex(in lines: [String], containingAny needles: [String]) -> Int? {
    lines.firstIndex { line in
        needles.contains { line.localizedCaseInsensitiveContains($0) }
    }
}

private func firstIndex(after index: Int, in lines: [String], containingAny needles: [String]) -> Int? {
    lines.indices.first { candidateIndex in
        candidateIndex > index && needles.contains { lines[candidateIndex].localizedCaseInsensitiveContains($0) }
    }
}

private func firstIndex(in lines: [String], exactlyMatchingAny needles: [String]) -> Int? {
    lines.firstIndex { line in
        needles.contains { line.compare($0, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }
}

private func firstLine(after index: Int, in lines: [String], matching predicate: (String) -> Bool = { _ in true }) -> String? {
    guard index < lines.endIndex else {
        return nil
    }

    for line in lines[(index + 1)...] where predicate(line) {
        return line
    }

    return nil
}

private func previousLine(before index: Int, in lines: [String]) -> String? {
    guard index > lines.startIndex else {
        return nil
    }

    for candidateIndex in stride(from: index - 1, through: lines.startIndex, by: -1) {
        let line = lines[candidateIndex]
        if !line.isEmpty {
            return line
        }
    }

    return nil
}

private func remainingProgressText(fromUsedText valueText: String) -> String {
    guard let usedProgress = percentage(from: valueText) else {
        return valueText
    }

    let remaining = max(0, min(1, 1 - usedProgress))
    return "\(Int((remaining * 100).rounded()))% remaining"
}

private func remainingProgress(fromUsedText valueText: String) -> Double? {
    guard let usedProgress = percentage(from: valueText) else {
        return nil
    }

    return max(0, min(1, 1 - usedProgress))
}

private func percentage(from valueText: String) -> Double? {
    guard let range = valueText.range(of: #"(\d+(?:[.,]\d+)?)\s*%"#, options: .regularExpression) else {
        return nil
    }

    let numberText = String(valueText[range])
        .replacingOccurrences(of: "%", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value = Double(numberText.replacingOccurrences(of: ",", with: ".")) else {
        return nil
    }

    return value / 100.0
}
