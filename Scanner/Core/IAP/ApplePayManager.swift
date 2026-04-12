//
//  ApplePayManager.swift
//  Scanner
//
//  StoreKit 2: load products, purchase, restore, and observe transaction updates.
//

import Foundation
import StoreKit

enum ApplePayError: LocalizedError {
    case productNotFound(String)
    case unverifiedTransaction
    case purchaseFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .productNotFound(let id):
            return "未找到商品：\(id)"
        case .unverifiedTransaction:
            return "交易验证失败"
        case .purchaseFailed(let message):
            return message
        case .userCancelled:
            return "已取消"
        }
    }
}

@MainActor
final class ApplePayManager {

    static let shared = ApplePayManager()

    /// Default weekly subscription product id (override via `APIConstants`).
    var defaultSubscriptionProductId: String { kIAPWeekly }

    private var productsByID: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    private init() {
        startListeningForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Products

    func loadProducts(ids: [String]? = nil) async throws -> [Product] {
        let idSet = Set(ids ?? [defaultSubscriptionProductId])
        let products = try await Product.products(for: Array(idSet))
        for p in products {
            productsByID[p.id] = p
        }
        return products
    }

    func product(for id: String) -> Product? {
        productsByID[id]
    }

    func displayPriceString(for productId: String) -> String? {
        productsByID[productId]?.displayPrice
    }

    /// StoreKit `displayPrice` + localized period suffix (e.g. `¥38.00` + `/周`).
    func displayPriceWithSubscriptionPeriodUnit(for productId: String) -> String? {
        guard let product = productsByID[productId] else { return nil }
        let price = product.displayPrice
        guard let subscription = product.subscription else { return price }
        return price + Self.localizedPeriodSuffix(subscription.subscriptionPeriod)
    }

    private static func localizedPeriodSuffix(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day:
            // Weekly products are often reported as 7 days instead of `.week`; normalize to 周.
            if value > 0, value % 7 == 0 {
                let weeks = value / 7
                return weeks == 1 ? "/周" : "/\(weeks)周"
            }
            return value == 1 ? "/天" : "/\(value)天"
        case .week:
            return value == 1 ? "/周" : "/\(value)周"
        case .month:
            return value == 1 ? "/月" : "/\(value)个月"
        case .year:
            return value == 1 ? "/年" : "/\(value)年"
        @unknown default:
            return ""
        }
    }

    // MARK: - Purchase

    func purchase(productId: String) async throws -> Transaction {
        if productsByID[productId] == nil {
            _ = try await loadProducts(ids: [productId])
        }
        guard let product = productsByID[productId] else {
            throw ApplePayError.productNotFound(productId)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await UserManager.shared.applyVerifiedTransaction(transaction)
            await transaction.finish()
            return transaction
        case .userCancelled:
            throw ApplePayError.userCancelled
        case .pending:
            throw ApplePayError.purchaseFailed("交易处理中，请稍后查看")
        @unknown default:
            throw ApplePayError.purchaseFailed("未知状态")
        }
    }

    // MARK: - Restore

    /// Syncs with App Store and reapplies active entitlements locally.
    func restorePurchases() async throws {
        try await AppStore.sync()
        try await refreshEntitlementsFromStore()
    }

    func refreshEntitlementsFromStore() async throws {
        var latestExpiration: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productType == .autoRenewable else { continue }
            guard transaction.revocationDate == nil else { continue }
            if subscriptionProductIDs.contains(transaction.productID) {
                if let exp = transaction.expirationDate {
                    if latestExpiration == nil || exp > latestExpiration! {
                        latestExpiration = exp
                    }
                }
            }
        }
        await UserManager.shared.applySubscriptionExpiration(latestExpiration)
    }

    // MARK: - Verification

    func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified:
            throw ApplePayError.unverifiedTransaction
        case .verified(let transaction):
            return transaction
        }
    }

    // MARK: - Transaction updates

    private func startListeningForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleUpdate(result)
            }
        }
    }

    private func handleUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            guard transaction.productType == .autoRenewable else {
                await transaction.finish()
                return
            }
            guard subscriptionProductIDs.contains(transaction.productID) else {
                await transaction.finish()
                return
            }
            await UserManager.shared.applyVerifiedTransaction(transaction)
            await transaction.finish()
        } catch {
            Logger.shared.log("Transaction update verify failed: \(error)", level: .error)
        }
    }
}

extension ApplePayManager {
    /// 界面展示用中文文案，不直接使用系统或 StoreKit 的 `localizedDescription`。
    static func userFacingPurchaseMessage(for error: Error) -> String {
        if let pay = error as? ApplePayError {
            switch pay {
            case .userCancelled:
                return "已取消"
            case .productNotFound:
                return "未找到订阅商品，请稍后重试"
            case .unverifiedTransaction:
                return "交易验证失败，请重试"
            case .purchaseFailed(let message):
                return message
            }
        }
        return "支付失败，请稍后重试"
    }

    /// 恢复订阅失败时的中文提示（不展示系统英文错误）。
    static func userFacingRestoreMessage(for error: Error) -> String {
        if let pay = error as? ApplePayError {
            switch pay {
            case .userCancelled:
                return "已取消"
            case .productNotFound:
                return "未找到订阅商品，请稍后重试"
            case .unverifiedTransaction:
                return "交易验证失败，请重试"
            case .purchaseFailed(let message):
                return message
            }
        }
        return "恢复订阅失败，请稍后重试"
    }
}

private let subscriptionProductIDs: Set<String> = [
    kIAPWeekly,
    kIAPWeeklyDiscount,
    kIAPMonthly,
    kIAPYearly
]
