import Foundation

public class CSBundle {
    // If you change the bundle name make sure to set these before
    // initializing the library
    public static var bundleIdentifier = "com.getbouncer.CardScan"
    public static var cardScanBundle: Bundle?
    public static var namedBundle = "CardScan"
    public static var namedBundleExtension = "bundle"
    
    // Public for testing
    public static func bundle() -> Bundle? {
        return Bundle.module
    }
    
    static func compiledModel(forResource: String, withExtension: String) -> URL? {
        guard let bundle = bundle() else {
            return nil
        }
        
        guard let modelcUrl = bundle.url(forResource: forResource, withExtension: withExtension) else {
            print("Could not find bundle named \"\(forResource).\(withExtension)\"")
            return nil
        }
        
        return modelcUrl
    }
}
