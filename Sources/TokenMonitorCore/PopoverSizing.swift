import Foundation

public struct PopoverLayout: Equatable, Sendable {
    public let height: Double
    public let contentHeight: Double
    public let scrolls: Bool

    public init(header: Double, content: Double, footer: Double, spacing: Double, maximumHeight: Double) {
        let chrome = max(0, header) + max(0, footer) + max(0, spacing)
        let naturalContent = max(0, content)
        height = min(chrome + naturalContent, max(0, maximumHeight))
        contentHeight = max(0, height - chrome)
        scrolls = naturalContent > contentHeight + 1
    }
}
