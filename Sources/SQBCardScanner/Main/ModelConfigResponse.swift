import Foundation

public struct ModelConfigResponse {
    public let modelVersion: String
    public let hash: String
    public let hashAlgorithm: String
    public let signedUrl: String
}
