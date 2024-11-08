import Foundation
import StoreKit


// Alias
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

open class KinglifyStore: NSObject, ObservableObject, SKRequestDelegate ,KinglifyHandler{
    @Published public private(set) var subscriptions: [Product] = []
    @Published public private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?
    @Published private(set) var introOfferEligibility: [String: Bool] = [:] // Track eligibility for each product
    @Published public var universalLinkURL: URL?
    
    
    @Published public var showPaywall: Bool = false
    @Published public var isLoading = true
    @Published var productIds: [String]
    
    private let refIdKey = "refId"
    private let offerIdKey = "offerId"
    var updateListenerTask: Task<Void, Error>? = nil
    
    var analytics:KinglifyAnalitics
    
    
    @MainActor
    public init(
        prodIds: [String],
        serverUrl: String?=backend_url,
        detectmeUrl: String? = detectme_url,
        detectmewaittime:Float?=detectme_wait_time
    ) {
  
           self.productIds = prodIds
        self.analytics = KinglifyAnalitics(serverUrl: serverUrl,detectmeUrl: detectmeUrl ,detectmewaittime: detectmewaittime);
           
           super.init()
           
           Task {
               isLoading = true
               await requestProducts()
               await updateCustomerProductStatus()
               isLoading = false
               
               print("Printing from KinglifyStore")
           }
        
    
       }


    
    deinit {
        updateListenerTask?.cancel()
    }
    
    public func handleIncomingURL(_ url: URL) {
                analytics.handleIncomingURL(url)
    }



  
           

       
    

    
    
    // Request available products from the App Store
    @MainActor
    func requestProducts() async {
        do {
            isLoading = true
            subscriptions = try await Product.products(for: productIds)
            await checkIntroOfferEligibility() // Check introductory offer eligibility after loading products
            await updateCustomerProductStatus()
            isLoading = false
            print("Subscriptions loaded.")
            // After loading subscriptions, print the intro offers
            await printIntroOffers()
        } catch {
            print("Failed to request products from App Store: \(error)")
        }
    }

    // Function to check and print the introductory offer details
    @MainActor
    func printIntroOffers() async {
        for product in subscriptions {
            if let subscriptionInfo = product.subscription, let introOffer = subscriptionInfo.introductoryOffer {
                let periodUnit = introOffer.period.unit
                let periodValue = introOffer.period.value
                let price = introOffer.price
                let localizedPrice = introOffer.displayPrice
                let paymentMode = introOffer.paymentMode
                
                print("Introductory Offer for product \(product.displayName):")
                print("  - Price: \(localizedPrice)")
                print("  - Subscription Period: \(periodValue) \(periodUnit)")
                print("  - Payment Mode: \(paymentMode)")
            } else {
                print("No introductory offer available for product \(product.displayName)")
            }
        }
    }

    // Check if the user is eligible for the introductory offer for each product
    @MainActor
    func checkIntroOfferEligibility() async {
        for product in subscriptions {
            if let subscriptionInfo = product.subscription {
                // Check if the user is eligible for an introductory offer
                let eligible = await subscriptionInfo.isEligibleForIntroOffer
                introOfferEligibility[product.id] = eligible
                print("Product \(product.id) is eligible for intro offer: \(eligible)")
            }
        }
    }

    // Handle product purchases, including receipt fetching and validation
    public func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            // Handle receipt after successful purchase
            await handleReceipt()
            await analytics.sendTransaction(transaction: transaction)
            await updateCustomerProductStatus()
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    // Verify the transaction
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // Handle receipt validation and processing
    func handleReceipt() async {
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           let receiptData = try? Data(contentsOf: receiptURL) {
            let base64Receipt = receiptData.base64EncodedString()
            print("Receipt Data: \(base64Receipt)")
            // Send the receipt to your server for further validation
            await validateReceiptOnServer(receiptData: base64Receipt)
            
        } else {
            print("Receipt not found. Refreshing receipt...")
            await refreshReceipt()
        }
    }
    
    // Refresh receipt if it's missing or corrupt
    func refreshReceipt() async {
        let request = SKReceiptRefreshRequest()
        request.delegate = self  // StoreViewModel is now the delegate
        request.start()
    }
    
    // Implement SKRequestDelegate method (no async)
    public func requestDidFinish(_ request: SKRequest) {
        print("Receipt refresh request finished.")
        // Retrieve the refreshed receipt
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL)
                let base64Receipt = receiptData.base64EncodedString()
                print("Refreshed Receipt Data: \(base64Receipt)")
                
                Task {
                    await validateReceiptOnServer(receiptData: base64Receipt)
                }
            } catch {
                print("Error retrieving the receipt: \(error)")
            }
        }
    }
    
    // Optionally handle request failure
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Receipt refresh request failed: \(error.localizedDescription)")
    }
    
    // Validate receipt on your server (example, needs server-side implementation)
    func validateReceiptOnServer(receiptData: String) async {
        print("Sending receipt to server for validation.")
        await analytics.sendReceiptToServer(receiptData: receiptData)
    }

    @MainActor
    public func updateCustomerProductStatus() async {
        var newPurchasedSubscriptions: [Product] = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                switch transaction.productType {
                case .autoRenewable:
                    if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                        if !newPurchasedSubscriptions.contains(where: { $0.id == subscription.id }) {
                            newPurchasedSubscriptions.append(subscription)
                        }
                    }
                default:
                    break
                }
                await transaction.finish()
            } catch {
                print("Failed to update customer product status: \(error)")
            }
        }
        purchasedSubscriptions = newPurchasedSubscriptions
    }

    public func restorePurchases() async {
        print("Restoring purchases...")
        do {
            try await AppStore.sync()
            print("Restoration completed.")
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }

    // Format product price per week
    public func weeklyPriceText(product: Product, numberOfWeeks: Decimal) -> String {
        let weeklyPrice = product.price / numberOfWeeks
        let currencySymbol = getCurrencySymbol(from: product.displayPrice)
        return formatPrice(weeklyPrice, with: currencySymbol)
    }

    // Format product price per month
    public func monthlyPriceText(product: Product, numberOfMonths: Decimal) -> String {
        let monthlyPrice = product.price / numberOfMonths
        let currencySymbol = getCurrencySymbol(from: product.displayPrice)
        return formatPrice(monthlyPrice, with: currencySymbol)
    }

    // Helper to format price with currency symbol
    func formatPrice(_ price: Decimal, with currencySymbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? ""
    }

    // Extract currency symbol from product price string
    func getCurrencySymbol(from displayPrice: String) -> String {
        let symbols = CharacterSet(charactersIn: "0123456789.-")
        return displayPrice.trimmingCharacters(in: symbols)
    }

    // Convert subscriptions to a string dictionary
    func subscriptionToString() -> [[String: String]] {
        let productData = subscriptions.map { product in
            return [
                "id": product.id,
                "title": product.displayName,
                "description": product.description,
                "price": product.price.formatted(),
                "display_price": product.displayPrice
            ]
        }
        return productData
    }

    // Convert purchased subscriptions to a string dictionary
    func purchasedDetailsToString() -> [[String: String]] {
        let productData = purchasedSubscriptions.map { product in
            return [
                "id": product.id,
                "title": product.displayName,
                "description": product.description,
                "price": product.price.formatted(),
                "display_price": product.displayPrice
            ]
        }
        return productData
    }

    // Purchase product by ID
    public func buyProductById(productId: String) async {
        if let product = subscriptions.first(where: { $0.id == productId }) {
            do {
                if try await purchase(product) != nil {
                    // Purchase was successful
                }
            } catch {
                print("Purchase failed: \(error)")
            }
        } else {
            print("Product not found")
        }
    }
}

// Error enumeration for store-related errors
public enum StoreError: Error {
    case failedVerification
}

// Extension to convert Date to ISO 8601 String
extension Date {
    var iso8601String: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter.string(from: self)
    }
}
