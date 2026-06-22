import Foundation
import SwiftData

/// A fixed monthly set-aside (family support, rent, EMI, savings…). Commitments
/// are NOT expenses — they reduce expendable income before any spending is
/// counted, so the money is "protected".
@Model
final class Commitment {
    var id: UUID = UUID()
    var name: String = ""
    var amountMinor: Int = 0
    var kindRaw: String = CommitmentKind.other.rawValue
    var colorHex: String = "FF9F0A"
    var createdAt: Date = Date.now
    var isActive: Bool = true

    init(
        name: String,
        amountMinor: Int,
        kind: CommitmentKind = .other,
        colorHex: String = "FF9F0A",
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.amountMinor = amountMinor
        self.kindRaw = kind.rawValue
        self.colorHex = colorHex
        self.createdAt = .now
        self.isActive = isActive
    }

    var kind: CommitmentKind {
        get { CommitmentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    /// Default symbol comes from the kind unless overridden in future.
    var symbolName: String { kind.symbolName }
}
