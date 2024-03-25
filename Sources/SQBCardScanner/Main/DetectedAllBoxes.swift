public struct DetectedAllBoxes {
    var allBoxes: [DetectedSSDBox] = []
    
    public init() {}
    
    public func toArray() -> [[String: Any]]{
        let frameArray = self.allBoxes.map{$0.toDict()}
        return frameArray
    }
}

