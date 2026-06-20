import AppKit
import ImageIO

@MainActor
final class GifAnimator {
    private struct Frame {
        let image: NSImage
        let delay: TimeInterval
    }

    private weak var imageView: NSImageView?
    private var frames: [Frame] = []
    private var currentFrameIndex = 0
    private var timer: Timer?
    private(set) var detectedFrameRate: CGFloat = 12

    init(imageView: NSImageView) {
        self.imageView = imageView
    }

    func start(url: URL, customFrameRate: CGFloat?) -> NSImage? {
        stop()

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else {
            return stillImage(from: source, at: 0)
        }

        var decodedFrames: [Frame] = []
        decodedFrames.reserveCapacity(frameCount)
        let customDelay = customFrameRate.map { 1.0 / TimeInterval(min(max($0, 1), 30)) }
        var totalOriginalDelay: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }

            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            let originalDelay = Self.frameDelay(from: source, at: index)
            totalOriginalDelay += originalDelay
            decodedFrames.append(Frame(image: image, delay: customDelay ?? originalDelay))
        }

        guard let firstFrame = decodedFrames.first else {
            return nil
        }

        frames = decodedFrames
        detectedFrameRate = Self.detectedFrameRate(frameCount: decodedFrames.count, totalDelay: totalOriginalDelay)
        currentFrameIndex = 0
        imageView?.image = firstFrame.image
        scheduleNextFrame(after: firstFrame.delay)
        return firstFrame.image
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        frames.removeAll(keepingCapacity: false)
        currentFrameIndex = 0
    }

    private func scheduleNextFrame(after delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        guard !frames.isEmpty else {
            return
        }

        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        let frame = frames[currentFrameIndex]
        imageView?.image = frame.image
        scheduleNextFrame(after: frame.delay)
    }

    private static func frameDelay(from source: CGImageSource, at index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }

        let unclampedDelay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let delay = unclampedDelay ?? gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval ?? 0.1
        return min(max(delay, 1.0 / 30.0), 1.0)
    }

    private static func detectedFrameRate(frameCount: Int, totalDelay: TimeInterval) -> CGFloat {
        guard frameCount > 0, totalDelay > 0 else {
            return 12
        }

        return min(max(CGFloat(Double(frameCount) / totalDelay), 1), 30)
    }

    private func stillImage(from source: CGImageSource, at index: Int) -> NSImage? {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
