import XCTest
@testable import pulse

@MainActor
final class FeatureAccessControllerTests: XCTestCase {
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
            PulseRuntimeIdentity.reminderEnhancementProductIdentifier
        )
        XCTAssertFalse(controller.hasReminderEnhancement)

        let outcome = try await controller.purchase()

        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(controller.hasReminderEnhancement)
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

        XCTAssertTrue(controller.hasReminderEnhancement)
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
        XCTAssertFalse(controller.hasReminderEnhancement)
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
        XCTAssertFalse(controller.hasReminderEnhancement)
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

        XCTAssertFalse(controller.hasReminderEnhancement)
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
            identifier: PulseRuntimeIdentity.reminderEnhancementProductIdentifier,
            displayName: "Reminder Enhancement",
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
