import Foundation
import UIKit

public class ActiveStateComputation {
    let queue: DispatchQueue
    var pendingComputations: [() -> Void] = []
    var isActive = false
    
    public init(label: String) {
        self.queue = DispatchQueue(label: "ActiveStateComputation \(label)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isActive = UIApplication.shared.applicationState == .active
            
            // We don't need to unregister these functions because the system will clean
            // them up for us
            NotificationCenter.default.addObserver(self, selector: #selector(self.willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    
    public func async(execute work: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let state = UIApplication.shared.applicationState
            guard state == .active, self.isActive else {
                self.pendingComputations.append(work)
                return
            }
        
            self.queue.async { work() }
        }
    }
    
    @objc func willResignActive() {
        assert(UIApplication.shared.applicationState == .active)
        assert(Thread.isMainThread)
        isActive = false
        queue.sync { }
    }
    
    @objc func didBecomeActive() {
        assert(UIApplication.shared.applicationState == .active)
        assert(Thread.isMainThread)
        isActive = true
        for work in pendingComputations {
            queue.async { work() }
        }
    }
}
