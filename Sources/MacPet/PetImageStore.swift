import AppKit
import UniformTypeIdentifiers

final class PetImageStore {
    static let supportedContentTypes: [UTType] = [
        .png,
        .jpeg,
        .gif,
        .tiff,
        .bmp
    ]

    private let imagePathKey = "selectedPetImagePath"
    private let sizeKey = "petDisplaySize"
    private let opacityKey = "petOpacity"
    private let usesOriginalGifTimingKey = "usesOriginalGifTiming"
    private let gifFrameRateKey = "gifFrameRate"
    private let displayIDKey = "petDisplayID"
    private let relativeXKey = "petRelativeX"
    private let relativeYKey = "petRelativeY"

    var savedImageURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: imagePathKey), !path.isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: imagePathKey)
        }
    }

    var displaySize: CGFloat {
        get {
            let value = UserDefaults.standard.double(forKey: sizeKey)
            return value > 0 ? CGFloat(value) : 180
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: sizeKey)
        }
    }

    var opacity: CGFloat {
        get {
            guard UserDefaults.standard.object(forKey: opacityKey) != nil else {
                return 1
            }

            return min(max(CGFloat(UserDefaults.standard.double(forKey: opacityKey)), 0.1), 1)
        }
        set {
            UserDefaults.standard.set(Double(min(max(newValue, 0.1), 1)), forKey: opacityKey)
        }
    }

    var usesOriginalGifTiming: Bool {
        get {
            guard UserDefaults.standard.object(forKey: usesOriginalGifTimingKey) != nil else {
                return true
            }

            return UserDefaults.standard.bool(forKey: usesOriginalGifTimingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: usesOriginalGifTimingKey)
        }
    }

    var gifFrameRate: CGFloat {
        get {
            let value = UserDefaults.standard.double(forKey: gifFrameRateKey)
            return value > 0 ? min(max(CGFloat(value), 1), 30) : 12
        }
        set {
            UserDefaults.standard.set(Double(min(max(newValue, 1), 30)), forKey: gifFrameRateKey)
        }
    }

    var displayID: CGDirectDisplayID? {
        get {
            let value = UserDefaults.standard.integer(forKey: displayIDKey)
            return value > 0 ? CGDirectDisplayID(value) : nil
        }
        set {
            UserDefaults.standard.set(Int(newValue ?? 0), forKey: displayIDKey)
        }
    }

    var relativePosition: CGPoint? {
        get {
            guard UserDefaults.standard.object(forKey: relativeXKey) != nil,
                  UserDefaults.standard.object(forKey: relativeYKey) != nil else {
                return nil
            }

            return CGPoint(
                x: UserDefaults.standard.double(forKey: relativeXKey),
                y: UserDefaults.standard.double(forKey: relativeYKey)
            )
        }
        set {
            UserDefaults.standard.set(Double(newValue?.x ?? 0), forKey: relativeXKey)
            UserDefaults.standard.set(Double(newValue?.y ?? 0), forKey: relativeYKey)
        }
    }
}
