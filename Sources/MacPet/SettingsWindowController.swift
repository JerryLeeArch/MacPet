import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let imageStore: PetImageStore
    private let petWindowController: PetWindowController

    private let imagePathLabel = NSTextField(labelWithString: "No image selected")
    private let sizeSlider = NSSlider(value: 180, minValue: 64, maxValue: 512, target: nil, action: nil)
    private let sizeField = NSTextField(string: "180")
    private let opacitySlider = NSSlider(value: 100, minValue: 10, maxValue: 100, target: nil, action: nil)
    private let opacityField = NSTextField(string: "100")
    private let originalGifTimingButton = NSButton(checkboxWithTitle: "Original GIF speed", target: nil, action: nil)
    private let gifFrameRateSlider = NSSlider(value: 12, minValue: 1, maxValue: 30, target: nil, action: nil)
    private let gifFrameRateField = NSTextField(string: "12")
    private lazy var gifFrameRateSection = makeGifFrameRateSection()
    private let displayPopup = NSPopUpButton()
    private let xField = NSTextField(string: "0")
    private let yField = NSTextField(string: "0")
    private let adjustButton = NSButton(title: "Adjust Image", target: nil, action: nil)

    init(imageStore: PetImageStore, petWindowController: PetWindowController) {
        self.imageStore = imageStore
        self.petWindowController = petWindowController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set My Pet"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildContent()
        refreshFromPetWindow()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showSettings() {
        refreshFromPetWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }

    func refreshFromPetWindow() {
        guard isWindowLoaded else {
            return
        }

        let placement = petWindowController.currentPlacement()
        let size = Int(placement.displaySize.rounded())
        let opacityPercent = Int((imageStore.opacity * 100).rounded())
        let usesOriginalGifTiming = imageStore.usesOriginalGifTiming
        let gifFrameRate = usesOriginalGifTiming ? petWindowController.detectedGifFrameRate() : imageStore.gifFrameRate
        let isGifSelected = imageStore.savedImageURL?.pathExtension.caseInsensitiveCompare("gif") == .orderedSame

        imagePathLabel.stringValue = imageStore.savedImageURL?.path ?? "No image selected"
        sizeSlider.doubleValue = Double(size)
        sizeField.stringValue = "\(size)"
        opacitySlider.doubleValue = Double(opacityPercent)
        opacityField.stringValue = "\(opacityPercent)"
        originalGifTimingButton.state = usesOriginalGifTiming ? .on : .off
        gifFrameRateSlider.doubleValue = Double(gifFrameRate)
        gifFrameRateField.stringValue = "\(Int(gifFrameRate.rounded()))"
        gifFrameRateSlider.isEnabled = !usesOriginalGifTiming
        gifFrameRateField.isEnabled = !usesOriginalGifTiming
        gifFrameRateSection.isHidden = !isGifSelected
        resizeWindowForVisibleSections(isGifSelected: isGifSelected)
        xField.stringValue = "\(Int(placement.relativeTopLeft.x.rounded()))"
        yField.stringValue = "\(Int(placement.relativeTopLeft.y.rounded()))"
        adjustButton.title = petWindowController.isManualAdjustmentActive() ? "Done Adjusting" : "Adjust Image"

        reloadDisplays(selecting: placement.displayID)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20)
        ])

        stack.addArrangedSubview(makeImageSection())
        stack.addArrangedSubview(makeSizeSection())
        stack.addArrangedSubview(makeOpacitySection())
        stack.addArrangedSubview(gifFrameRateSection)
        stack.addArrangedSubview(makeDisplaySection())
        stack.addArrangedSubview(makePositionSection())
    }

    private func makeImageSection() -> NSView {
        let chooseButton = NSButton(title: "Choose Image...", target: self, action: #selector(chooseImage))
        imagePathLabel.lineBreakMode = .byTruncatingMiddle
        imagePathLabel.maximumNumberOfLines = 1

        let row = NSStackView(views: [chooseButton, imagePathLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        imagePathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
    }

    private func makeSizeSection() -> NSView {
        let label = NSTextField(labelWithString: "Long edge")
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true

        sizeSlider.target = self
        sizeSlider.action = #selector(sizeSliderChanged)
        sizeSlider.widthAnchor.constraint(equalToConstant: 210).isActive = true

        sizeField.alignment = .right
        sizeField.delegate = self
        sizeField.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let row = NSStackView(views: [label, sizeSlider, sizeField, NSTextField(labelWithString: "px")])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func makeOpacitySection() -> NSView {
        let label = NSTextField(labelWithString: "Opacity")
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true

        opacitySlider.target = self
        opacitySlider.action = #selector(opacitySliderChanged)
        opacitySlider.widthAnchor.constraint(equalToConstant: 210).isActive = true

        opacityField.alignment = .right
        opacityField.delegate = self
        opacityField.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let row = NSStackView(views: [label, opacitySlider, opacityField, NSTextField(labelWithString: "%")])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func makeGifFrameRateSection() -> NSView {
        let label = NSTextField(labelWithString: "GIF FPS")
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true

        originalGifTimingButton.target = self
        originalGifTimingButton.action = #selector(originalGifTimingChanged)

        gifFrameRateSlider.target = self
        gifFrameRateSlider.action = #selector(gifFrameRateSliderChanged)
        gifFrameRateSlider.widthAnchor.constraint(equalToConstant: 120).isActive = true

        gifFrameRateField.alignment = .right
        gifFrameRateField.delegate = self
        gifFrameRateField.widthAnchor.constraint(equalToConstant: 42).isActive = true

        let row = NSStackView(views: [
            label,
            originalGifTimingButton,
            gifFrameRateSlider,
            gifFrameRateField,
            NSTextField(labelWithString: "fps")
        ])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func makeDisplaySection() -> NSView {
        let label = NSTextField(labelWithString: "Display")
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true

        displayPopup.target = self
        displayPopup.action = #selector(displayChanged)
        displayPopup.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let row = NSStackView(views: [label, displayPopup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func makePositionSection() -> NSView {
        let label = NSTextField(labelWithString: "Position")
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true

        xField.alignment = .right
        yField.alignment = .right
        xField.delegate = self
        yField.delegate = self
        xField.widthAnchor.constraint(equalToConstant: 70).isActive = true
        yField.widthAnchor.constraint(equalToConstant: 70).isActive = true

        let coordinateRow = NSStackView(views: [
            label,
            NSTextField(labelWithString: "X"),
            xField,
            NSTextField(labelWithString: "Y"),
            yField
        ])
        coordinateRow.orientation = .horizontal
        coordinateRow.alignment = .centerY
        coordinateRow.spacing = 8

        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 90).isActive = true

        adjustButton.target = self
        adjustButton.action = #selector(adjustImage)
        let adjustRow = NSStackView(views: [spacer, adjustButton])
        adjustRow.orientation = .horizontal
        adjustRow.alignment = .centerY
        adjustRow.spacing = 8

        let section = NSStackView(views: [coordinateRow, adjustRow])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        return section
    }

    private func reloadDisplays(selecting displayID: CGDirectDisplayID?) {
        displayPopup.removeAllItems()

        for (index, screen) in NSScreen.screens.enumerated() {
            let id = PetWindowController.displayID(for: screen)
            let frame = screen.visibleFrame
            let title = "\(index + 1). \(screen.localizedName) (\(Int(frame.width)) x \(Int(frame.height)))"
            displayPopup.addItem(withTitle: title)
            displayPopup.lastItem?.representedObject = id.map { NSNumber(value: $0) }

            if id == displayID {
                displayPopup.selectItem(at: index)
            }
        }

        if displayPopup.selectedItem == nil, displayPopup.numberOfItems > 0 {
            displayPopup.selectItem(at: 0)
        }
    }

    private func selectedScreen() -> NSScreen? {
        guard let item = displayPopup.selectedItem,
              let number = item.representedObject as? NSNumber else {
            return NSScreen.main
        }

        let displayID = CGDirectDisplayID(number.uint32Value)
        return NSScreen.screens.first { PetWindowController.displayID(for: $0) == displayID } ?? NSScreen.main
    }

    private func resizeWindowForVisibleSections(isGifSelected: Bool) {
        guard let window else {
            return
        }

        let targetHeight: CGFloat = isGifSelected ? 420 : 370
        guard abs(window.frame.height - targetHeight) > 0.5 else {
            return
        }

        var frame = window.frame
        frame.origin.y += frame.height - targetHeight
        frame.size.height = targetHeight
        window.setFrame(frame, display: true)
    }

    private func applySizeField() {
        let value = CGFloat(sizeField.doubleValue)
        petWindowController.applyDisplaySize(value)
        refreshFromPetWindow()
    }

    private func applyOpacityField() {
        let value = CGFloat(opacityField.doubleValue) / 100
        petWindowController.applyOpacity(value)
        refreshFromPetWindow()
    }

    private func applyGifFrameRateField() {
        let value = CGFloat(gifFrameRateField.doubleValue)
        petWindowController.applyGifPlayback(usesOriginalTiming: false, frameRate: value)
        refreshFromPetWindow()
    }

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose a local pet image"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = PetImageStore.supportedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        imageStore.savedImageURL = url
        petWindowController.showImage(at: url)
        refreshFromPetWindow()
    }

    @objc private func sizeSliderChanged() {
        let value = Int(sizeSlider.doubleValue.rounded())
        sizeField.stringValue = "\(value)"
        petWindowController.applyDisplaySize(CGFloat(value))
    }

    @objc private func opacitySliderChanged() {
        let value = Int(opacitySlider.doubleValue.rounded())
        opacityField.stringValue = "\(value)"
        petWindowController.applyOpacity(CGFloat(value) / 100)
    }

    @objc private func originalGifTimingChanged() {
        let usesOriginalTiming = originalGifTimingButton.state == .on
        petWindowController.applyGifPlayback(
            usesOriginalTiming: usesOriginalTiming,
            frameRate: CGFloat(gifFrameRateSlider.doubleValue)
        )
        refreshFromPetWindow()
    }

    @objc private func gifFrameRateSliderChanged() {
        let value = Int(gifFrameRateSlider.doubleValue.rounded())
        gifFrameRateField.stringValue = "\(value)"
        petWindowController.applyGifPlayback(usesOriginalTiming: false, frameRate: CGFloat(value))
    }

    @objc private func displayChanged() {
        applyPosition()
    }

    @objc private func applyPosition() {
        guard let screen = selectedScreen() else {
            return
        }

        petWindowController.move(
            to: screen,
            relativeTopLeft: CGPoint(x: xField.doubleValue, y: yField.doubleValue)
        )
        refreshFromPetWindow()
    }

    @objc private func adjustImage() {
        if petWindowController.isManualAdjustmentActive() {
            petWindowController.endManualAdjustment()
        } else {
            petWindowController.beginManualAdjustment()
        }
        refreshFromPetWindow()
    }
}

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else {
            return
        }

        if textField === sizeField {
            applySizeField()
        } else if textField === opacityField {
            applyOpacityField()
        } else if textField === gifFrameRateField {
            applyGifFrameRateField()
        } else if textField === xField || textField === yField {
            applyPosition()
        }
    }
}
