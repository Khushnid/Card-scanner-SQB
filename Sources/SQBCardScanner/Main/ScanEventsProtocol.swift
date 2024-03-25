import CoreGraphics

public protocol ScanEvents {
    mutating func onNumberRecognized(number: String, expiry: Expiry?, numberBoundingBox: CGRect, expiryBoundingBox: CGRect?, croppedCardSize: CGSize, squareCardImage: CGImage, fullCardImage: CGImage, centeredCardState: CenteredCardState?, uxFrameConfidenceValues: UxFrameConfidenceValues?, flashForcedOn: Bool, numberBoxesInFullImageFrame: [CGRect])
    mutating func onScanComplete(scanStats: ScanStats)
    mutating func onFrameDetected(croppedCardSize: CGSize, squareCardImage: CGImage, fullCardImage: CGImage, centeredCardState: CenteredCardState?, uxFrameConfidenceValues: UxFrameConfidenceValues?, flashForcedOn: Bool)
}
