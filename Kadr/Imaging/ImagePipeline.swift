import CoreImage
import CoreGraphics

/// What to draw: the edit plus the subject mask, if the user removed the background.
struct Recipe {
    var snapshot: EditorSnapshot
    var mask: CIImage?
}

/// Core Image pipeline. The same code runs on the small preview and on the
/// full-size photo, so what you see is what you export.
///
/// Only filter parameter names that Apple documents are used, because a wrong
/// name would crash at run time.
enum ImagePipeline {
    private static let context = CIContext()
    private static let srgb = CGColorSpace(name: CGColorSpace.sRGB)

    static func render(source: CIImage, recipe: Recipe) -> CGImage? {
        let snap = recipe.snapshot
        var image = source

        if snap.background != .original, let mask = recipe.mask {
            image = replaceBackground(image, mask: mask, mode: snap.background)
        }
        image = geometry(image, snap.transform)
        image = crop(image, snap.transform.crop)
        image = adjust(image, snap.adjustments)
        image = applyFilter(image, snap.filter, intensity: snap.filterIntensity)

        return context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: srgb)
    }

    // MARK: - Steps

    private static func replaceBackground(_ image: CIImage, mask: CIImage, mode: BackgroundMode) -> CIImage {
        let extent = image.extent
        var scaledMask = mask
        if abs(mask.extent.width - extent.width) > 0.5 || abs(mask.extent.height - extent.height) > 0.5 {
            scaledMask = mask.transformed(by: CGAffineTransform(
                scaleX: extent.width / mask.extent.width,
                y: extent.height / mask.extent.height))
        }

        let background: CIImage
        switch mode {
        case .original:
            return image
        case .transparent:
            background = CIImage(color: CIColor.clear).cropped(to: extent)
        case .color(let hex):
            let color = CIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                                green: CGFloat((hex >> 8) & 0xFF) / 255,
                                blue: CGFloat(hex & 0xFF) / 255)
            background = CIImage(color: color).cropped(to: extent)
        case .blur:
            background = image.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": extent.width * 0.02])
                .cropped(to: extent)
        }

        return image
            .applyingFilter("CIBlendWithMask", parameters: [
                "inputBackgroundImage": background,
                "inputMaskImage": scaledMask
            ])
            .cropped(to: extent)
    }

    private static func geometry(_ input: CIImage, _ t: TransformState) -> CIImage {
        var image = input
        let turns = ((t.quarterTurns % 4) + 4) % 4
        for _ in 0..<turns {
            image = image.transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
            image = moveToOrigin(image)
        }
        if t.flipH {
            image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            image = moveToOrigin(image)
        }
        return image
    }

    private static func crop(_ input: CIImage, _ r: CGRect) -> CIImage {
        if r == EditorSnapshot.fullCrop { return input }
        let e = input.extent
        let rect = CGRect(
            x: e.minX + r.minX * e.width,
            y: e.minY + (1 - r.maxY) * e.height,
            width: max(1, r.width * e.width),
            height: max(1, r.height * e.height)
        ).integral
        return moveToOrigin(input.cropped(to: rect))
    }

    private static func adjust(_ input: CIImage, _ a: Adjustments) -> CIImage {
        var image = input
        let extent = input.extent

        if a.brightness != 0 || a.contrast != 0 || a.saturation != 0 {
            image = image.applyingFilter("CIColorControls", parameters: [
                "inputBrightness": a.brightness * 0.35,
                "inputContrast": 1 + a.contrast * 0.5,
                "inputSaturation": max(0, 1 + a.saturation)
            ])
        }

        if a.warmth != 0 {
            let k = a.warmth * 0.18
            image = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1 + k, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1 - k, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ])
        }

        if a.shadows != 0 || a.highlights != 0 {
            image = image.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputShadowAmount": a.shadows,
                "inputHighlightAmount": 1 - a.highlights
            ])
        }

        if a.sharpness > 0 {
            image = image.applyingFilter("CISharpenLuminance", parameters: [
                "inputSharpness": a.sharpness * 1.5
            ])
        }

        if a.blur > 0 {
            image = image.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": a.blur * extent.width * 0.02])
                .cropped(to: extent)
        }

        if a.vignette > 0 {
            image = image.applyingFilter("CIVignette", parameters: [
                "inputIntensity": a.vignette * 1.5,
                "inputRadius": 1.5
            ])
        }

        return image
    }

    private static func applyFilter(_ input: CIImage, _ preset: FilterPreset, intensity: Double) -> CIImage {
        if preset == .none || intensity <= 0 { return input }

        let filtered: CIImage
        switch preset {
        case .none:
            return input
        case .vivid:
            filtered = input
                .applyingFilter("CIVibrance", parameters: ["inputAmount": 0.9])
                .applyingFilter("CIColorControls", parameters: ["inputContrast": 1.08, "inputSaturation": 1.1])
        case .chrome:
            filtered = input.applyingFilter("CIPhotoEffectChrome")
        case .fade:
            filtered = input.applyingFilter("CIPhotoEffectFade")
        case .instant:
            filtered = input.applyingFilter("CIPhotoEffectInstant")
        case .process:
            filtered = input.applyingFilter("CIPhotoEffectProcess")
        case .transfer:
            filtered = input.applyingFilter("CIPhotoEffectTransfer")
        case .mono:
            filtered = input.applyingFilter("CIPhotoEffectMono")
        case .noir:
            filtered = input.applyingFilter("CIPhotoEffectNoir")
        case .tonal:
            filtered = input.applyingFilter("CIPhotoEffectTonal")
        case .sepia:
            filtered = input.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 1.0])
        case .cool:
            filtered = tint(input, red: 0.9, blue: 1.1)
        case .warm:
            filtered = tint(input, red: 1.1, blue: 0.9)
        }

        if intensity >= 0.999 { return filtered }
        return input.applyingFilter("CIDissolveTransition", parameters: [
            "inputTargetImage": filtered,
            "inputTime": intensity
        ])
    }

    // MARK: - Helpers

    private static func tint(_ input: CIImage, red: CGFloat, blue: CGFloat) -> CIImage {
        input.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: red, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: blue, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
    }

    private static func moveToOrigin(_ image: CIImage) -> CIImage {
        let e = image.extent
        return image.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
    }
}
