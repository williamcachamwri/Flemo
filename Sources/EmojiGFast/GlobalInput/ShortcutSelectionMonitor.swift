import Cocoa

class ShortcutSelectionMonitor {
    private weak var appState: AppState?
    private var monitor: Any?
    private var emojiHandler: ((Emoji) -> Void)?
    private var gifHandler: ((GIFItem) -> Void)?

    init(appState: AppState) {
        self.appState = appState
    }

    func start(emojiHandler: @escaping (Emoji) -> Void, gifHandler: @escaping (GIFItem) -> Void) {
        self.emojiHandler = emojiHandler
        self.gifHandler = gifHandler
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
            } else if digit < appState.suggestions.count + appState.gifSuggestions.count {
                let gifIndex = digit - appState.suggestions.count
                guard gifIndex < appState.gifSuggestions.count else { return }
                self.gifHandler?(appState.gifSuggestions[gifIndex])
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}
