import Foundation
import StoreKit

public enum PulseEnhancementCapability: String, CaseIterable, Identifiable, Sendable {
    case interfaceThemes
    case advancedWidgetCompositions
    case scheduledLiveActivity

    public var id: String { rawValue }
}

public enum PulseEnhancementContract {
    public static let productIdentifier = "co.fanr.pulse.enhancement.lifetime"
    public static let entitlementRefreshInterval: TimeInterval = 15 * 60
    public static let currentCapabilities: [PulseEnhancementCapability] = [
        .interfaceThemes,
        .advancedWidgetCompositions,
        .scheduledLiveActivity,
    ]
}

@MainActor
public enum PulseStoreKitEntitlementReader {
    public static func hasCurrentEntitlement(for productIdentifier: String) async -> Bool {
        guard let result = await Transaction.currentEntitlement(for: productIdentifier),
              case .verified(let transaction) = result,
              transaction.productID == productIdentifier,
              transaction.revocationDate == nil,
              !transaction.isUpgraded else {
            return false
        }
        if let expirationDate = transaction.expirationDate {
            return expirationDate > .now
        }
        return true
    }
}
