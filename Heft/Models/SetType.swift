// iOS 26+ only. No #available guards.

import Foundation

enum SetType: String, Codable, CaseIterable, Sendable {
    case normal
    case warmup
    case dropset
}
