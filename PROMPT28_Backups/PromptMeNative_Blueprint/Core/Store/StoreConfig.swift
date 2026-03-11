import Foundation

enum StoreProductID {
    static let proMonthly       = "com.prompt28.pro.monthly"
    static let proYearly        = "com.prompt28.pro.yearly"
    static let unlimitedMonthly = "com.prompt28.unlimited.monthly"
    static let unlimitedYearly  = "com.prompt28.unlimited.yearly"

    static var all: [String] {
        [proMonthly, proYearly, unlimitedMonthly, unlimitedYearly]
    }
}
