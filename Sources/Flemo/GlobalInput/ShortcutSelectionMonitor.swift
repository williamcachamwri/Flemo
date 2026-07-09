import Cocoa

class ShortcutSelectionMonitor {
    private weak var appState: AppState?
    private var monitor: Any?
    private var emojiHandler: ((Emoji) -> Void)?

    init(appState: AppState) {
        self.appState = appState
    }

    func start(emojiHandler: @escaping (Emoji) -> Void) {
        self.emojiHandler = emojiHandler
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let appState = self.appState,
                  appState.isShowingSuggestions,
                  appState.numberShortcutEnabled,
                  event.modifierFlags.contains(.command)
            else { return }

            guard let chars = event.charactersIgnoringModifiers,
                  let digit = Int(chars),
                  digit >= 0, digit <= 9
            else { return }

            if digit < appState.suggestions.count {
                self.emojiHandler?(appState.suggestions[digit].emoji)
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}
