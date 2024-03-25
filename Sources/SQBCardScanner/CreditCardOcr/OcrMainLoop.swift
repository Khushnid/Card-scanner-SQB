import UIKit

public protocol OcrMainLoopDelegate: AnyObject {
    func complete(creditCardOcrResult: CreditCardOcrResult)
    func prediction(prediction: CreditCardOcrPrediction, squareCardImage: CGImage, fullCardImage: CGImage, state: MainLoopState)
    func showCardDetails(number: String?, expiry: String?, name: String?)
    func showCardDetailsWithFlash(number: String?, expiry: String?, name: String?)
    func showWrongCard(number: String?, expiry: String?, name: String?)
    func showNoCard()
    func shouldUsePrediction(errorCorrectedNumber: String?, prediction: CreditCardOcrPrediction) -> Bool
}


public protocol MachineLearningLoop: AnyObject {
    func push(fullImage: CGImage, roiRectangle: CGRect)
}


open class OcrMainLoop : MachineLearningLoop {
    public enum AnalyzerType {
        case apple
        case ssd
    }
    
    public var scanStats = ScanStats()
    
    public weak var mainLoopDelegate: OcrMainLoopDelegate?
    public var errorCorrection = ErrorCorrection(stateMachine: OcrMainLoopStateMachine())
    var imageQueue: [(CGImage, CGRect)] = []
    public var imageQueueSize = 2
    var analyzerQueue: [CreditCardOcrImplementation] = []
    let mutexQueue = DispatchQueue(label: "OcrMainLoopMutex")
    var inBackground = false
    var machineLearningQueues: [DispatchQueue] = []
    var userDidCancel = false
    
    public init(analyzers: [AnalyzerType] = [.ssd, .apple]) {
        var ocrImplementations: [CreditCardOcrImplementation] = []
        for analyzer in analyzers {
            let queueLabel = "\(analyzer) OCR ML"
            switch (analyzer) {
            case .ssd:
                if #available(iOS 11.2, *) {
                    ocrImplementations.append(SSDCreditCardOcr(dispatchQueueLabel: queueLabel))
                }
            case .apple:
                if #available(iOS 13.0, *) {
                    ocrImplementations.append(AppleCreditCardOcr(dispatchQueueLabel: queueLabel))
                }
            }
        }
        setupMl(ocrImplementations: ocrImplementations)
    }
    
    /// Note: you must call this function in your constructor
    public func setupMl(ocrImplementations: [CreditCardOcrImplementation]) {
        scanStats.model = "ssd+apple"
        for ocrImplementation in ocrImplementations {
            analyzerQueue.append(ocrImplementation)
        }
        registerAppNotifications()
    }
    
    func reset() {
        mutexQueue.async {
            self.errorCorrection = self.errorCorrection.reset()
        }
    }
    
    static func warmUp() {
        // TODO(stk): Implement this later
    }
    
    // see the Correctness Criteria note in the comments above for why this is correct
    // Make sure you call this from the main dispatch queue
    func userCancelled() {
        userDidCancel = true
        mutexQueue.sync { [weak self] in
            guard let self = self else { return }
            self.scanStats.userCanceled = userDidCancel
            if self.scanStats.success == nil {
                self.scanStats.success = false
                self.scanStats.endTime = Date()
                self.mainLoopDelegate = nil
            }
        }
    }
    
    public func push(fullImage: CGImage, roiRectangle: CGRect) {
        mutexQueue.sync {
            guard !inBackground else { return }
            // only keep the latest images
            imageQueue.insert((fullImage, roiRectangle), at: 0)
            while imageQueue.count > imageQueueSize {
                let _ = imageQueue.popLast()
            }
            
            // if we have any analyzers waiting, fire them off now
            guard let ocr = analyzerQueue.popLast() else { return }
            analyzer(ocr: ocr)
        }
    }

    func postAnalyzerToQueueAndRun(ocr: CreditCardOcrImplementation) {
        mutexQueue.async { [weak self] in
            guard let self = self else { return }
            self.analyzerQueue.insert(ocr, at: 0)
            // only kick off the next analyzer if there is an image in the queue
            if self.imageQueue.count > 0 {
                guard let ocr = self.analyzerQueue.popLast() else { return }
                self.analyzer(ocr: ocr)
            }
        }
    }
    
    func analyzer(ocr: CreditCardOcrImplementation) {
        ocr.dispatchQueue.async { [weak self] in
            var fullImage: CGImage?
            var roiRectangle: CGRect?
            
            // grab an image and roi from the image queue. If the image queue is empty then add ourselves
            // back to the analyzer queue
            self?.mutexQueue.sync {
                guard !(self?.inBackground ?? false) else {
                    self?.analyzerQueue.insert(ocr, at: 0)
                    return
                }
                guard let (fullImageFromQueue, roiRectangleFromQueue) = self?.imageQueue.popLast() else {
                    self?.analyzerQueue.insert(ocr, at: 0)
                    return
                }
                fullImage = fullImageFromQueue
                roiRectangle = roiRectangleFromQueue
            }
            
            guard let image = fullImage, let roi = roiRectangle else { return }
            
            // run our ML model, add ourselves back to the analyzer queue unless we have a result
            // and the result is finished
            let prediction = ocr.recognizeCard(in: image, roiRectangle: roi)
            self?.mutexQueue.async {
                guard let self = self else { return }
                self.scanStats.scans += 1
                let delegate = self.mainLoopDelegate
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    guard !self.userDidCancel else { return }
                    guard let squareCardImage = image.squareCardImage(roiRectangle: roi) else { return }
                    delegate?.prediction(prediction: prediction, squareCardImage: squareCardImage, fullCardImage: image, state: self.errorCorrection.stateMachine.loopState())
                }
                guard let result = self.combine(prediction: prediction), result.state == .finished else {
                    self.postAnalyzerToQueueAndRun(ocr: ocr)
                    return
                }
            }
        }
    }
    
    func combine(prediction: CreditCardOcrPrediction) -> CreditCardOcrResult? {
        guard mainLoopDelegate?.shouldUsePrediction(errorCorrectedNumber: errorCorrection.number, prediction: prediction) ?? true else { return nil }
        guard let result = errorCorrection.add(prediction: prediction) else { return nil }
        let delegate = mainLoopDelegate
        if result.state == .finished && scanStats.success == nil {
            scanStats.success = true
            scanStats.endTime = Date()
            mainLoopDelegate = nil
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.userDidCancel else { return }
            switch (result.state) {
            case MainLoopState.initial, MainLoopState.cardOnly:
                delegate?.showNoCard()
            case MainLoopState.ocrIncorrect:
                delegate?.showWrongCard(number: result.number, expiry: result.expiry, name: result.name)
            case MainLoopState.ocrOnly, MainLoopState.ocrAndCard, MainLoopState.ocrDelayForCard:
                delegate?.showCardDetails(number: result.number, expiry: result.expiry, name: result.name)
            case .ocrForceFlash:
                delegate?.showCardDetailsWithFlash(number: result.number, expiry: result.expiry, name: result.name)
            case MainLoopState.finished:
                delegate?.complete(creditCardOcrResult: result)
            case MainLoopState.nameAndExpiry:
                break
            }
        }
        return result
    }
    
    // MARK: -backrounding logic
    @objc func willResignActive() {
        // make sure that no new images get pushed to our image buffer
        // and we clear out the image buffer
        mutexQueue.sync {
            self.inBackground = true
            self.imageQueue = []
        }
    }
    
    @objc func didBecomeActive() {
        mutexQueue.sync {
            self.inBackground = false
            self.errorCorrection = self.errorCorrection.reset()
        }
    }
    
    func registerAppNotifications() {
        // We don't need to unregister these functions because the system will clean
        // them up for us
        NotificationCenter.default.addObserver(self, selector: #selector(self.willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}
