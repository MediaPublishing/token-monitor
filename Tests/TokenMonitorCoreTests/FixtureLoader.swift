import Foundation
import Testing

enum FixtureLoader {
    static func text(named name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")
        return try String(contentsOf: #require(url), encoding: .utf8)
    }
}
