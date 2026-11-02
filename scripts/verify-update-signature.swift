import CryptoKit
import Foundation

guard CommandLine.arguments.count == 4,
      let keyData = Data(base64Encoded: CommandLine.arguments[2]),
      let signature = Data(base64Encoded: CommandLine.arguments[3]) else {
    fatalError("Expected archive path, public key, and Ed25519 signature")
}
let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
guard key.isValidSignature(signature, for: archive) else {
    fatalError("Invalid Sparkle update signature")
}
print("Sparkle Ed25519 signature verified")
