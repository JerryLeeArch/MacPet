import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let imageStore = PetImageStore()
    private lazy var petWindowController = PetWindowController(imageStore: imageStore)
    private lazy var settingsWindowController = SettingsWindowController(
        imageStore: imageStore,
        petWindowController: petWindowController
    )
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBar()
        petWindowController.onPlacementChanged = { [weak self] in
            self?.settingsWindowController.refreshFromPetWindow()
        }
        petWindowController.show()
        loadSavedImageIfAvailable()
    }

    private func configureMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "P"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Set My Pet...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MacPet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    private func loadSavedImageIfAvailable() {
        guard let imageURL = imageStore.savedImageURL else {
            petWindowController.showPlaceholder()
            return
        }

        petWindowController.showImage(at: imageURL)
    }

    @objc private func resetPosition() {
        petWindowController.resetPosition()
    }

    @objc private func openSettings() {
        settingsWindowController.showSettings()
    }
}
