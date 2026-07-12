import Foundation

enum Constants {
    static let appName = "Flemo"
    static let defaultTriggerCharacter = ":"
    static let legacyDefaultTriggerCharacter = "`"
    static let defaultMinTriggerLength = 2
    static let maxSuggestionResults = 10
    static let overlayPanelWidth: CGFloat = 340
    static let overlayPanelMaxHeight: CGFloat = 360

    enum MenuBarIcon: String {
        case happy = "face.smiling"
        case keyboard = "character.cursor.ibeam"
        case sparkle = "sparkle.magnifyingglass"

        var systemName: String { rawValue }
    }
}
