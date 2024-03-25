import Foundation

@objc public enum CardNetwork: Int {
    case VISA
    case MASTERCARD
    case AMEX
    case DISCOVER
    case UNIONPAY
    case JCB
    case DINERSCLUB
    case REGIONAL
    case UNKNOWN
    case TRANSPORT
    case UZCARDS
    case HUMOCARD
    
    public func toString() -> String {
        switch self {
        case .VISA: return "Visa"
        case .MASTERCARD: return "MasterCard"
        case .AMEX: return "Amex"
        case .DISCOVER: return "Discover"
        case .UNIONPAY: return "Union Pay"
        case .JCB: return "Jcb"
        case .DINERSCLUB: return "Diners Club"
        case .REGIONAL: return "Regional"
        case .UNKNOWN: return "Unknown"
        case .TRANSPORT: return "Transport"
        case .UZCARDS: return "UzCards"
        case .HUMOCARD: return "HumoCard"
        }
    }
}
