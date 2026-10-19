import Vision
import CoreImage

enum CutoutError: Error {
    case noSubject
}

/// Background removal with Apple's on-device Vision framework (iOS 17+).
enum Cutout {
    /// Returns a grey-scale mask the size of `image`: white where the subject is.
    static func makeMask(for image: CIImage) throws -> CIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw CutoutError.noSubject
        }
        let buffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        return CIImage(cvPixelBuffer: buffer)
    }
}
