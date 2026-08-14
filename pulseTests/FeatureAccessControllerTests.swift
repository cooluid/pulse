import XCTest
@testable import PulseCore
@testable import pulse

@MainActor
final class FeatureAccessControllerTests: XCTestCase {
    func testCurrentCapabilityDirectoryPublishesOnlyDeliveredCapabilities() {
        XCTAssertEqual(
            PulseEnhancementContract.currentCapabilities,
            [.advancedWidgetCompositions, .scheduledLiveActivity]
        )
        XCTAssertEqual(
            Set(PulseEnhancementContract.currentCapabilities).count,
            PulseEnhancementContract.currentCapabilities.count
        )
    }

    func testStoreKitFixtureMatchesTheSharedEnhancementContract() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(
            contentsOf: projectRoot
                .appendingPathComponent("Config", isDirectory: true)
                .appendingPathComponent("PulseEnhancements.storekit")
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let products = try XCTUnwrap(root["products"] as? [[String: Any]])

        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(
            products.first?["productID"] as? String,
            PulseEnhancementContract.productIdentifier
        )
        XCTAssertEqual(products.first?["type"] as? String, "NonConsumable")
    }

    func testPurchaseDerivesEntitlementWithoutPersistingAProFlag() async throws {
        let client = TestStoreKitAccessClient()
        let controller = FeatureAccessController(
            client: client,
            listensForTransactionUpdates: false
        )
        await controller.start()

        XCTAssertEqual(controller.productState, .available)
        XCTAssertEqual(
            controller.product?.identifier,
            PulseEnhancementContract.productIdentifier
        )
        XCTAssertFalse(controller.hasEnhancement)

        let outcome = try await controller.purchase()

        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(controller.hasEnhancement)
        XCTAssertEqual(client.purchaseCount, 1)
    }

    func testUnavailableProductNeverInventsPriceOrStartsPurchase() async {
        let client = TestStoreKitAccessClient(product: nil)
        let controller = FeatureAccessController(
            client: client,
            listensForTransactionUpdates: false
        )
        await controller.start()

        XCTAssertEqual(controller.productState, .unavailable)
        XCTAssertNil(controller.product)

        do {
            _ = try await controller.purchase()
            XCTFail("An unavailable product must not start a purchase.")
        } catch {
            XCTAssertEqual(error as? StoreAccessError, .productUnavailable)
        }
        XCTAssertEqual(client.purchaseCount, 0)
    }

    func testRestoreRefreshesVerifiedEntitlement() async throws {
        let client = TestStoreKitAccessClient()
        client.entitlementAfterSynchronization = true
        let controller = FeatureAccessController(
            client: client,
            listensForTransactionUpdates: false
        )
        await controller.start()

        try await controller.restore()

        XCTAssertTrue(controller.hasEnhancement)
        XCTAssertEqual(client.synchronizationCount, 1)
    }

    func testPendingPurchaseDoesNotUnlockEntitlement() async throws {
        let client = TestStoreKitAccessClient(purchaseOutcome: .pending)
        let controller = FeatureAccessController(
            client: client,
            listensForTransactionUpdates: false
        )
        await controller.start()

        let outcome = try await controller.purchase()

        XCTAssertEqual(outcome, .pending)
        XCTAssertEqual(controller.operation, .pending)
        XCTAssertFalse(controller.hasEnhancement)
    }

    func testCancelledPurchaseDoesNotUnlockEntitlement() async throws {
        let client = TestStoreKitAccessClient(purchaseOutcome: .cancelled)
        let controller = FeatureAccessController(
            client: client,
            listensForTransactionUpdates: false
        )
        await controller.start()

        let outcome = try await controller.purchase()

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertNil(controller.operation)
        XCTAssertFalse(controller.hasEnhancement)
    }

    func testRestoreWithoutAnEntitlementReportsNothingToRestore() async {
        let client = TestStoreKitAccessClient()
        let controller = FeatureAccessController(
            client: client,
            listensForTransactionUpdates: false
        )
        await controller.start()

        do {
            try await controller.restore()
            XCTFail("Restore must not invent an entitlement.")
        } catch {
            XCTAssertEqual(error as? StoreAccessError, .nothingToRestore)
        }

        XCTAssertFalse(controller.hasEnhancement)
        XCTAssertNil(controller.operation)
    }
}

@MainActor
private final class TestStoreKitAccessClient: StoreKitAccessClient {
    let product: StoreProductPresentation?
    var entitlement = false
    var entitlementAfterSynchronization = false
    let purchaseOutcome: StorePurchaseOutcome
    private(set) var purchaseCount = 0
    private(set) var synchronizationCount = 0

    init(
        product: StoreProductPresentation? = StoreProductPresentation(
            identifier: PulseEnhancementContract.productIdentifier,
            displayName: "Pulse · Advanced Features",
            description: "Test product",
            displayPrice: "¥18.00"
        ),
        purchaseOutcome: StorePurchaseOutcome = .purchased
    ) {
        self.product = product
        self.purchaseOutcome = purchaseOutcome
    }

    func loadProduct(identifier: String) async throws -> StoreProductPresentation? {
        product
    }

    func hasCurrentEntitlement(identifier: String) async -> Bool {
        entitlement
    }

    func purchase(identifier: String) async throws -> StorePurchaseOutcome {
        purchaseCount += 1
        if purchaseOutcome == .purchased {
            entitlement = true
        }
        return purchaseOutcome
    }

    func synchronize() async throws {
        synchronizationCount += 1
        entitlement = entitlementAfterSynchronization
    }
}
