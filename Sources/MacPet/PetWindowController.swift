import AppKit

@MainActor
final class PetWindowController: NSWindowController {
    private let imageView = DraggableImageView()
    private let adjustmentOverlayView = AdjustmentOverlayView()
    private let imageStore: PetImageStore
    private lazy var gifAnimator = GifAnimator(imageView: imageView)
    private let defaultSize: CGFloat = 180
    private var isAdjustmentModeActive = false
    private var isClampingWindowFrame = false
    private var isResizingWindowFrame = false
    private var currentImageAspectRatio: CGFloat = 1
    private var isShowingPlaceholder = false
    private var currentImageURL: URL?
    private var resizeAnchor = PetResizeAnchor.bottomLeft

    var onPlacementChanged: (() -> Void)?

    init(imageStore: PetImageStore) {
        self.imageStore = imageStore
        let savedSize = imageStore.displaySize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: savedSize, height: savedSize)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)
        configure(panel)
        configureImageView(in: panel)
        applyOpacity(imageStore.opacity)
        restoreSavedPosition()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func beginManualAdjustment() {
        setManualAdjustmentActive(true)
        window?.orderFrontRegardless()
    }

    func endManualAdjustment() {
        setManualAdjustmentActive(false)
        savePlacement()
    }

    func showImage(at url: URL) {
        currentImageURL = url

        if url.pathExtension.caseInsensitiveCompare("gif") == .orderedSame {
            showGif(at: url)
            return
        }

        gifAnimator.stop()
        guard let image = NSImage(contentsOf: url) else {
            showPlaceholder()
            return
        }

        currentImageAspectRatio = Self.aspectRatio(for: image)
        isShowingPlaceholder = false
        imageView.image = image
        imageView.animates = false
        resizeWindowToCurrentImage()
    }

    func showPlaceholder() {
        currentImageURL = nil
        gifAnimator.stop()
        currentImageAspectRatio = 1
        isShowingPlaceholder = true
        let displaySize = imageStore.displaySize
        imageView.image = PlaceholderPetImage.make(size: NSSize(width: displaySize, height: displaySize))
        imageView.animates = false
        resizeWindowToCurrentImage()
    }

    private func showGif(at url: URL) {
        let customFrameRate = imageStore.usesOriginalGifTiming ? nil : imageStore.gifFrameRate
        guard let firstFrame = gifAnimator.start(url: url, customFrameRate: customFrameRate) else {
            showPlaceholder()
            return
        }

        currentImageAspectRatio = Self.aspectRatio(for: firstFrame)
        isShowingPlaceholder = false
        imageView.animates = false
        resizeWindowToCurrentImage()
    }

    func resetPosition() {
        let targetScreen = screen(matching: imageStore.displayID) ?? NSScreen.main
        guard let screenFrame = targetScreen?.visibleFrame else {
            return
        }

        let size = window?.frame.size ?? NSSize(width: defaultSize, height: defaultSize)
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )
        window?.setFrameOrigin(origin)
        savePlacement()
    }

    func applyDisplaySize(_ size: CGFloat) {
        let clampedSize = min(max(size, 64), 512)
        imageStore.displaySize = clampedSize

        guard window != nil else {
            return
        }

        if imageView.image == nil || isShowingPlaceholder {
            showPlaceholder()
        } else {
            resizeWindowToCurrentImage()
        }

        savePlacement(shouldUpdateResizeAnchor: false)
    }

    func applyOpacity(_ opacity: CGFloat) {
        let clampedOpacity = min(max(opacity, 0.1), 1)
        imageStore.opacity = clampedOpacity
        window?.alphaValue = clampedOpacity
    }

    func applyGifPlayback(usesOriginalTiming: Bool, frameRate: CGFloat) {
        imageStore.usesOriginalGifTiming = usesOriginalTiming
        imageStore.gifFrameRate = frameRate

        guard let currentImageURL,
              currentImageURL.pathExtension.caseInsensitiveCompare("gif") == .orderedSame else {
            return
        }

        showGif(at: currentImageURL)
    }

    func detectedGifFrameRate() -> CGFloat {
        gifAnimator.detectedFrameRate
    }

    func move(to screen: NSScreen, relativeTopLeft: CGPoint) {
        guard let window else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = window.frame.size
        let maxX = max(0, visibleFrame.width - size.width)
        let maxY = max(0, visibleFrame.height - size.height)
        let x = min(max(relativeTopLeft.x, 0), maxX)
        let y = min(max(relativeTopLeft.y, 0), maxY)

        let origin = CGPoint(
            x: visibleFrame.minX + x,
            y: visibleFrame.maxY - y - size.height
        )

        window.setFrameOrigin(origin)
        savePlacement()
    }

    func currentPlacement() -> PetPlacement {
        let currentScreen = currentScreen() ?? NSScreen.main
        let displayID = currentScreen.flatMap(Self.displayID)
        let relativePosition = currentScreen.map { relativeTopLeftPosition(in: $0) } ?? .zero

        return PetPlacement(
            displayID: displayID,
            relativeTopLeft: relativePosition,
            displaySize: imageStore.displaySize
        )
    }

    func isManualAdjustmentActive() -> Bool {
        isAdjustmentModeActive
    }

    private func configure(_ panel: NSPanel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.delegate = self
    }

    private func configureImageView(in panel: NSPanel) {
        let size = panel.frame.size
        imageView.frame = NSRect(origin: .zero, size: size)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.canDrawSubviewsIntoLayer = true

        adjustmentOverlayView.frame = NSRect(origin: .zero, size: size)
        adjustmentOverlayView.autoresizingMask = [.width, .height]
        adjustmentOverlayView.isHidden = true

        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.addSubview(imageView)
        contentView.addSubview(adjustmentOverlayView)
        panel.contentView = contentView
    }

    private func restoreSavedPosition() {
        resizeWindowToCurrentImage()

        guard let displayID = imageStore.displayID,
              let screen = screen(matching: displayID),
              let relativePosition = imageStore.relativePosition else {
            resetPosition()
            return
        }

        move(to: screen, relativeTopLeft: relativePosition)
    }

    private func savePlacement(shouldUpdateResizeAnchor: Bool = true) {
        guard let screen = currentScreen() else {
            return
        }

        clampWindowToVisibleFrame(of: screen)

        if shouldUpdateResizeAnchor {
            updateResizeAnchor(for: screen)
        }

        imageStore.displayID = Self.displayID(for: screen)
        imageStore.relativePosition = relativeTopLeftPosition(in: screen)
        onPlacementChanged?()
    }

    private func setManualAdjustmentActive(_ isActive: Bool) {
        isAdjustmentModeActive = isActive
        window?.ignoresMouseEvents = !isActive
        imageView.isDragEnabled = isActive
        adjustmentOverlayView.isDragEnabled = isActive
        adjustmentOverlayView.isHidden = !isActive
    }

    private func resizeWindowToCurrentImage() {
        guard let window else {
            return
        }

        let newSize = renderedSize(forLongEdge: imageStore.displaySize)
        let frame = resizeAnchor.resizedFrame(from: window.frame, to: newSize)

        isResizingWindowFrame = true
        window.setFrame(frame, display: true)
        isResizingWindowFrame = false

        imageView.frame = NSRect(origin: .zero, size: newSize)
        adjustmentOverlayView.frame = NSRect(origin: .zero, size: newSize)
        window.contentView?.frame = NSRect(origin: .zero, size: newSize)
    }

    private func updateResizeAnchor(for screen: NSScreen) {
        guard let frame = window?.frame else {
            return
        }

        resizeAnchor = PetResizeAnchor.corner(for: frame, in: screen.visibleFrame)
    }

    private func renderedSize(forLongEdge longEdge: CGFloat) -> NSSize {
        if currentImageAspectRatio >= 1 {
            return NSSize(width: longEdge, height: longEdge / currentImageAspectRatio)
        }

        return NSSize(width: longEdge * currentImageAspectRatio, height: longEdge)
    }

    private func clampWindowToVisibleFrame(of screen: NSScreen) {
        guard let window, !isClampingWindowFrame else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        let clampedX = min(max(frame.minX, visibleFrame.minX), visibleFrame.maxX - frame.width)
        let clampedY = min(max(frame.minY, visibleFrame.minY), visibleFrame.maxY - frame.height)
        let clampedOrigin = CGPoint(x: clampedX, y: clampedY)

        guard clampedOrigin != frame.origin else {
            return
        }

        isClampingWindowFrame = true
        window.setFrameOrigin(clampedOrigin)
        isClampingWindowFrame = false
    }

    private func currentScreen() -> NSScreen? {
        guard let frame = window?.frame else {
            return nil
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }

    private func screen(matching displayID: CGDirectDisplayID?) -> NSScreen? {
        guard let displayID else {
            return nil
        }

        return NSScreen.screens.first { Self.displayID(for: $0) == displayID }
    }

    private func relativeTopLeftPosition(in screen: NSScreen) -> CGPoint {
        guard let frame = window?.frame else {
            return .zero
        }

        let visibleFrame = screen.visibleFrame
        return CGPoint(
            x: frame.minX - visibleFrame.minX,
            y: visibleFrame.maxY - frame.maxY
        )
    }

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    private static func aspectRatio(for image: NSImage) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else {
            return 1
        }

        return image.size.width / image.size.height
    }
}

private final class DraggableImageView: NSImageView {
    var isDragEnabled = false

    override var mouseDownCanMoveWindow: Bool {
        isDragEnabled
    }
}

private final class AdjustmentOverlayView: NSView {
    var isDragEnabled = false

    override var mouseDownCanMoveWindow: Bool {
        isDragEnabled
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.22).cgColor
        layer?.borderColor = NSColor.systemRed.cgColor
        layer?.borderWidth = 3
    }

    required init?(coder: NSCoder) {
        nil
    }
}

extension PetWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard !isClampingWindowFrame, !isResizingWindowFrame else {
            return
        }

        savePlacement()
    }
}

struct PetPlacement {
    let displayID: CGDirectDisplayID?
    let relativeTopLeft: CGPoint
    let displaySize: CGFloat
}
