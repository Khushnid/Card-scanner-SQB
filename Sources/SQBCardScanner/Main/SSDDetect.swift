import Foundation
import os.log
import UIKit
import CoreML

public struct SsdDetect {
    static var ssdModel: SSD? = nil
    static var priors:[CGRect]? = nil
    
    // SSD Model Parameters
    static let ssdImageWidth = 300
    static let ssdImageHeight = 300
    static let probThreshold: Float = 0.3
    static let iouThreshold: Float = 0.45
    static let candidateSize = 200
    static let topK = 10

    /* We don't use the following constants, these values are determined at run time
    *  Regardless, this is good information to keep around.
    *  let NoOfClasses = 14
    *  let TotalNumberOfPriors = 2766
    *  let NoOfCordinates = 4
    */
    
    static public func warmUp() {
        // TODO(stk): implement this after we finish up dynamic model updating
    }
    
    public init() {
        if SsdDetect.priors == nil {
            SsdDetect.priors = PriorsGen.combinePriors()
        }
        
    }
    
    public static func initializeModels(contentsOf url: URL) {
        if SsdDetect.ssdModel == nil {
            SsdDetect.ssdModel = try? SSD(contentsOf: url)
        }
        
    }
    
    public static func isModelLoaded() -> Bool {
        return self.ssdModel != nil
    }
    
    func detectObjects(prediction: SSDOutput, image: UIImage) -> DetectedAllBoxes {
        var DetectedSSDBoxes = DetectedAllBoxes()
        var startTime = CFAbsoluteTimeGetCurrent()
        let boxes = prediction.getBoxes()
        let scores = prediction.getScores()
        var endTime = CFAbsoluteTimeGetCurrent() - startTime
        os_log("%@", type: .debug, "Get boxes and scores from mult-array time: \(endTime)")
        
        startTime = CFAbsoluteTimeGetCurrent()
        let normalizedScores = prediction.fasterSoftmax2D(scores)
        let regularBoxes = prediction.convertLocationsToBoxes(locations: boxes, priors: SsdDetect.priors ?? PriorsGen.combinePriors(), centerVariance: 0.1, sizeVariance: 0.2)
        let cornerFormBoxes = prediction.centerFormToCornerForm(regularBoxes: regularBoxes)

        let predAPI = PredictionAPI()
        let result:Result = predAPI.predictionAPI(scores:normalizedScores, boxes: cornerFormBoxes, probThreshold: SsdDetect.probThreshold, iouThreshold: SsdDetect.iouThreshold, candidateSize: SsdDetect.candidateSize, topK: SsdDetect.topK)
        endTime = CFAbsoluteTimeGetCurrent() - startTime
        os_log("%@", type: .debug, "Rest of the forward pass time: \(endTime)")
        
        for idx in 0..<result.pickedBoxes.count {
            DetectedSSDBoxes.allBoxes.append(DetectedSSDBox(category: result.pickedLabels[idx], conf: result.pickedBoxProbs[idx], XMin: Double(result.pickedBoxes[idx][0]), YMin: Double(result.pickedBoxes[idx][1]), XMax: Double(result.pickedBoxes[idx][2]), YMax: Double(result.pickedBoxes[idx][3]), imageSize: image.size))
        }


       return DetectedSSDBoxes
        
    }
    
    
    public func predict(image: UIImage) -> DetectedAllBoxes? {

        guard let pixelBuffer = image.pixelBuffer(width: SsdDetect.ssdImageWidth, height: SsdDetect.ssdImageHeight) else {
            os_log("Couldn't convert to pixel buffer", type: .debug)
            return nil
        }
        
        
        guard let detectModel = SsdDetect.ssdModel else {
            os_log("Model not initialized", type: .debug)
            return nil
        }
       
        let startTime = CFAbsoluteTimeGetCurrent()
        let input = SSDInput(_0: pixelBuffer)
        guard let prediction = try? detectModel.prediction(input: input) else {
            os_log("Couldn't predict", type: .debug)
            return nil
        }
        let endTime = CFAbsoluteTimeGetCurrent() - startTime
        os_log("%@", type: .debug, "Model Run without post-process time: \(endTime)")

        return self.detectObjects(prediction: prediction, image: image)
    }
    

}
