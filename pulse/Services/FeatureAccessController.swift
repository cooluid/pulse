import Foundation
import Observation
import PulseCore
import StoreKit

struct StoreProductPresentation: Equatable, Sendable {
    let identifier: String
    let displayName: String
    let description: String
    let displayPrice: String
}

enum StoreProductLoadState: Equatable, Sendable {
    case loading
    case available
    case unavailable
}

enum StorePurchaseOperation: Equatable, Sendable {
    case purchasing
    case restoring
    case pending
}

enum StorePurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
}

enum StoreAccessError: Error, Equatable {
    case productUnavailable
    case verificationFailed
    case nothingToRestore
}

@MainActor
protocol StoreKitAccessClient: AnyObject {
    func loadProduct(identifier: String) async throws -> StoreProductPresentation?
    func hasCurrentEntitlement(identifier: String) async -> Bool
    func purchase(identifier: String) async throws -> StorePurchaseOutcome
    func synchronize() async throws
}

@MainActor
final class StoreKit2AccessClient: StoreKitAccessClient {
    private var productsByIdentifier: [String: Product] = [:]

    func loadProduct(identifier: String) async throws -> StoreProductPresentation? {
        guard let product = try await Product.products(for: [identifier]).first,
              product.id == identifier,
              product.type == .nonConsumable else {
            productsByIdentifier.removeValue(forKey: identifier)
            return nil
        }

        productsByIdentifier[identifier] = product
        return StoreProductPresentation(
            identifier: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice
        )
    }

    func hasCurrentEntitlement(identifier: String) async -> Bool {
        await PulseStoreKitEntitlementReader.hasCurrentEntitlement(for: identifier)
    }

    func purchase(identifier: String) async throws -> StorePurchaseOutcome {
        guard let product = productsByIdentifier[identifier] else {
            throw StoreAccessError.productUnavailable
        }

        switch try await product.purchase() {
        case .success(.verified(let transaction)):
            guard transaction.productID == identifier else {
                throw StoreAccessError.verificationFailed
            }
            await transaction.finish()
            return .purchased
        case .success(.unverified):
            throw StoreAccessError.verificationFailed
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw StoreAccessError.verificationFailed
        }
    }

    func synchronize() async throws {
        try await AppStore.sync()
    }
}

@MainActor
@Observable
final class FeatureAccessController {
    @ObservationIgnored private let client: any StoreKitAccessClient
    @ObservationIgnored private let listensForTransactionUpdates: Bool
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var productLoadTask: Task<Void, Never>?
    @ObservationIgnored private var entitlementRefreshRevision = 0

    private(set) var productState: StoreProductLoadState = .loading
    private(set) var product: StoreProductPresentation?
    private(set) var operation: StorePurchaseOperation?
    private(set) var hasEnhancement = false
    private(set) var entitlementIsResolved = false

    @ObservationIgnored var accessDidChange: (@MainActor (Bool) -> Void)?
    @ObservationIgnored var accessWasRevoked: (@MainActor () -> Void)?

    init(
        client: any StoreKitAccessClient = StoreKit2AccessClient(),
        listensForTransactionUpdates: Bool = true
    ) {
        self.client = client
        self.listensForTransactionUpdates = listensForTransactionUpdates
    }

    deinit {
        transactionUpdatesTask?.cancel()
        productLoadTask?.cancel()
    }

    func start() async {
        await prepareForLaunch()
        await refreshProduct()
    }

    func prepareForLaunch() async {
        startObservingTransactionsIfNeeded()
        await refreshEntitlement()
    }

    func loadProductInBackground() {
        guard productLoadTask == nil else { return }
        productLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshProduct()
            self.productLoadTask = nil
        }
    }

    func refresh() async {
        await refreshEntitlement()
        if let productLoadTask {
            await productLoadTask.value
            return
        }
        await refreshProduct()
    }

    private func refreshProduct() async {
        productState = .loading
        do {
            product = try await client.loadProduct(
                identifier: PulseEnhancementContract.productIdentifier
            )
            productState = product == nil ? .unavailable : .available
        } catch {
            product = nil
            productState = .unavailable
        }
    }

    func purchase() async throws -> StorePurchaseOutcome {
        guard productState == .available, product != nil else {
            throw StoreAccessError.productUnavailable
        }
        operation = .purchasing
        do {
            let outcome = try await client.purchase(
                identifier: PulseEnhancementContract.productIdentifier
            )
            switch outcome {
            case .purchased:
                operation = nil
                await refreshEntitlement()
            case .pending:
                operation = .pending
            case .cancelled:
                operation = nil
            }
            return outcome
        } catch {
            operation = nil
            throw error
        }
    }

    func restore() async throws {
        operation = .restoring
        do {
            try await client.synchronize()
            await refreshEntitlement()
            operation = nil
            guard hasEnhancement else {
                throw StoreAccessError.nothingToRestore
            }
        } catch {
            operation = nil
            throw error
        }
    }

    private func refreshEntitlement() async {
        entitlementRefreshRevision += 1
        let revision = entitlementRefreshRevision
        let entitlement = await client.hasCurrentEntitlement(
            identifier: PulseEnhancementContract.productIdentifier
        )
        guard revision == entitlementRefreshRevision else { return }
        let wasResolved = entitlementIsResolved
        let previousEntitlement = hasEnhancement
        entitlementIsResolved = true
        hasEnhancement = entitlement
        if entitlement {
            operation = nil
        }
        if !wasResolved || previousEntitlement != entitlement {
            accessDidChange?(entitlement)
        }
    }

    private func startObservingTransactionsIfNeeded() {
        guard listensForTransactionUpdates, transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                var wasRevoked = false
                if case .verified(let transaction) = result,
                   transaction.productID == PulseEnhancementContract.productIdentifier {
                    wasRevoked = transaction.revocationDate != nil
                    await transaction.finish()
                }
                await self.refreshEntitlement()
                if wasRevoked {
                    self.accessWasRevoked?()
                }
            }
        }
    }
}

#if DEBUG
@MainActor
final class UITestStoreKitAccessClient: StoreKitAccessClient {
    private var hasEntitlement: Bool

    init(hasEntitlement: Bool) {
        self.hasEntitlement = hasEntitlement
    }

    func loadProduct(identifier: String) async throws -> StoreProductPresentation? {
        StoreProductPresentation(
            identifier: identifier,
            displayName: String(localized: "store.title"),
            description: String(localized: "store.hero.promise"),
            displayPrice: "¥28.00"
        )
    }

    func hasCurrentEntitlement(identifier: String) async -> Bool {
        hasEntitlement
    }

    func purchase(identifier: String) async throws -> StorePurchaseOutcome {
        hasEntitlement = true
        return .purchased
    }

    func synchronize() async throws {}
}
#endif
