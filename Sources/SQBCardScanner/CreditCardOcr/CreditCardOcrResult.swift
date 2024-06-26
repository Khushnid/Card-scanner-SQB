import Foundation

public class CreditCardOcrResult: MachineLearningResult {
    public let mostRecentPrediction: CreditCardOcrPrediction
    public let number: String
    public let expiry: String?
    public let name: String?
    public let state: MainLoopState
    
    // this is only used by Card Verify and the Liveness check and filled in by the UxModel
    public var hasCenteredCard: CenteredCardState?
    
    init(mostRecentPrediction: CreditCardOcrPrediction, number: String, expiry: String?, name: String?, state: MainLoopState, duration: Double, frames: Int) {
        self.mostRecentPrediction = mostRecentPrediction
        self.number = number
        self.expiry = expiry
        self.name = name
        self.state = state
        super.init(duration: duration, frames: frames)
    }
    
    public var expiryMonth: String? {
        return expiry.flatMap { $0.split(separator: "/").first.map { String($0) }}
    }
    public var expiryYear: String? {
        return expiry.flatMap { $0.split(separator: "/").last.map { String($0) }}
    }
    
    public static func finishedWithNonNumberSideCard(prediction: CreditCardOcrPrediction, duration: Double, frames: Int) -> CreditCardOcrResult {
        let result = CreditCardOcrResult(mostRecentPrediction: prediction, number: "", expiry: nil, name: nil, state: .finished, duration: duration, frames: frames)
        result.hasCenteredCard = .nonNumberSide
        return result
    }
}
