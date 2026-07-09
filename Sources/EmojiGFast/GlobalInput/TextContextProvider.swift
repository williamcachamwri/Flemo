import Cocoa
import os.log

struct TextContext {
    let textBeforeCursor: String
    let cursorScreenPosition: NSPoint
    let cursorScreenBounds: CGRect
    let focusedElementBounds: CGRect
}

class TextContextProvider {
    static let shared = TextContextProvider()
    private let log = OSLog(subsystem: "com.emoji-g-fast", category: "TextCtx")
    private static let maxContextLength = 100
    private static let recentAnchorLifetime: TimeInterval = 45

    private struct RecentInputAnchor {
        let rect: CGRect
        let appPID: pid_t
        let timestamp: Date
    }

    private var recentInputAnchor: RecentInputAnchor?

    @discardableResult
    func rememberPotentialInputAnchor(at point: CGPoint) -> Bool {
        guard let app = focusedApplication(),
              let appPID = processID(of: app)
        else { return false }

        var hitElement: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hitElement) == .success,
              let hitElement,
              let rect = textEntryBounds(from: hitElement)
        else { return false }

        recentInputAnchor = RecentInputAnchor(rect: rect, appPID: appPID, timestamp: Date())
        return true
    }

    var cursorScreenPosition: NSPoint? {
        guard let (element, cursor) = textInputElementAndCursor() else { return nil }
        return cursorScreenPosition(element: element, cursor: cursor)
    }

    func textBoundsBeforeCursor(length: Int) -> CGRect? {
        guard length > 0,
              let (element, cursor) = textInputElementAndCursor()
        else { return nil }
        let boundedLength = min(length, cursor)
        let start = max(0, cursor - boundedLength)
        return screenBounds(element: element, range: CFRange(location: start, length: boundedLength))
    }

    func bestAnchorBoundsBeforeCursor(length: Int) -> CGRect? {
        guard let element = textInputElement() else { return recentAnchorBounds() }

        if let cursor = selectedCursor(in: element), length > 0 {
            let boundedLength = min(length, cursor)
            let start = max(0, cursor - boundedLength)
            if let textRect = screenBounds(element: element, range: CFRange(location: start, length: boundedLength)),
               isUsableAnchor(textRect) {
                return textRect
            }
        }

        if let markerRect = selectedTextMarkerBounds(element: element),
           isUsableAnchor(markerRect) {
            return markerRect
        }

        guard let cursor = selectedCursor(in: element) else {
            return approximateTypingBounds(element: element, typedLength: length)
                ?? bestElementBounds(element: element)
                ?? recentAnchorBounds()
        }

        if let cursorRect = cursorScreenBounds(element: element, cursor: cursor),
           isUsableAnchor(cursorRect) {
            return cursorRect
        }

        if let approximateRect = approximateTypingBounds(element: element, typedLength: length) {
            return approximateRect
        }

        return bestElementBounds(element: element)
            ?? recentAnchorBounds()
    }

    func getTextContext() -> TextContext? {
        guard let element = textInputElement() else { return nil }
        guard let elementBounds = bestElementBounds(element: element) ?? focusedElementBounds(element: element) else { return nil }

        let cursor = selectedCursor(in: element)
        let text: String
        if let cursor,
           let rangedText = textBeforeCursor(element: element, cursor: cursor) {
            text = rangedText
        } else if let value = textValue(element: element), !value.isEmpty {
            text = String(value.suffix(Self.maxContextLength))
        } else {
            return nil
        }

        let cursorBounds: CGRect
        if let cursor,
           let bounds = cursorScreenBounds(element: element, cursor: cursor) {
            cursorBounds = bounds
        } else {
            cursorBounds = elementBounds
        }

        let pos = NSPoint(x: cursorBounds.midX, y: cursorBounds.midY)
        return TextContext(
            textBeforeCursor: text,
            cursorScreenPosition: pos,
            cursorScreenBounds: cursorBounds,
            focusedElementBounds: elementBounds
        )
    }

    private func textInputElementAndCursor() -> (AXUIElement, Int)? {
        guard let element = textInputElement(),
              let cursor = selectedCursor(in: element)
        else { return nil }
        return (element, cursor)
    }

    private func textInputElement() -> AXUIElement? {
        guard let focus = focusedElement() else { return nil }

        if let nested = focusedDescendant(of: focus),
           isTextEntryElement(nested) {
            return nested
        }

        if isTextEntryElement(focus) {
            return focus
        }

        var current: AXUIElement? = focus
        for _ in 0..<5 {
            guard let candidate = current else { break }
            if isTextEntryElement(candidate) {
                return candidate
            }

            var parentVal: CFTypeRef?
            guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parentVal) == .success,
                  let parent = parentVal
            else { break }
            current = (parent as! AXUIElement)
        }

        if let focusRect = focusedElementBounds(element: focus),
           focusRect.width <= 420,
           focusRect.height <= 220,
           let child = firstTextEntryDescendant(of: focus, maxDepth: 4) {
            return child
        }

        return nil
    }

    private func focusedElement() -> AXUIElement? {
        guard let appElem = focusedApplication() else { return nil }
        var focus: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &focus) == .success,
              let focusElem = focus else { return nil }
        let element = focusElem as! AXUIElement
        return element
    }

    private func focusedApplication() -> AXUIElement? {
        let sys = AXUIElementCreateSystemWide()
        var app: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedApplicationAttribute as CFString, &app) == .success,
              let appElem = app
        else { return nil }
        return (appElem as! AXUIElement)
    }

    private func selectedCursor(in element: AXUIElement) -> Int? {
        var rangeVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeVal) == .success else { return nil }
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeVal as! AXValue, .cfRange, &range) else { return nil }
        return range.location + range.length
    }

    private func textValue(element: AXUIElement) -> String? {
        var valueVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueVal) == .success,
              let value = valueVal as? String
        else { return nil }
        return value
    }

    private func selectedTextMarkerBounds(element: AXUIElement) -> CGRect? {
        var markerRangeVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &markerRangeVal) == .success,
              let markerRange = markerRangeVal
        else { return nil }

        var boundsVal: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXBoundsForTextMarkerRange" as CFString,
            markerRange,
            &boundsVal
        ) == .success,
              let boundsAX = boundsVal
        else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsAX as! AXValue, .cgRect, &rect),
              rect.width.isFinite, rect.height.isFinite,
              rect.origin.x.isFinite, rect.origin.y.isFinite
        else { return nil }
        return normalizedCaretRect(rect)
    }

    private func textBeforeCursor(element: AXUIElement, cursor: Int) -> String? {
        let start = max(0, cursor - Self.maxContextLength)
        let len = cursor - start
        guard len > 0 else { return nil }
        var range = CFRange(location: start, length: len)
        let param = AXValueCreate(.cfRange, &range)!
        var textVal: CFTypeRef?
        if AXUIElementCopyParameterizedAttributeValue(element, "AXStringForRange" as CFString, param, &textVal) == .success,
           let text = textVal as? String {
            return text
        }
        guard let value = textValue(element: element) else { return nil }
        let nsValue = value as NSString
        let safeStart = max(0, cursor - Self.maxContextLength)
        let safeLen = cursor - safeStart
        guard safeLen > 0 else { return nil }
        return nsValue.substring(with: NSRange(location: safeStart, length: safeLen))
    }

    private func cursorScreenPosition(element: AXUIElement, cursor: Int) -> NSPoint? {
        guard let rect = cursorScreenBounds(element: element, cursor: cursor) else { return nil }
        return NSPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height / 2)
    }

    private func cursorScreenBounds(element: AXUIElement, cursor: Int) -> CGRect? {
        let targetRange = CFRange(location: cursor, length: 0)
        guard let rect = screenBounds(element: element, range: targetRange) else { return nil }
        return normalizedCaretRect(rect)
    }

    private func focusedElementBounds(element: AXUIElement) -> CGRect? {
        var positionVal: CFTypeRef?
        var sizeVal: CFTypeRef?
        let rect: CGRect
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionVal) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success,
           let positionAX = positionVal,
           let sizeAX = sizeVal {
            var point = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(positionAX as! AXValue, .cgPoint, &point),
                  AXValueGetValue(sizeAX as! AXValue, .cgSize, &size)
            else { return nil }
            rect = CGRect(origin: point, size: size)
        } else {
            var frameVal: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &frameVal) == .success,
                  let frameAX = frameVal
            else { return nil }
            var frame = CGRect.zero
            guard AXValueGetValue(frameAX as! AXValue, .cgRect, &frame) else { return nil }
            rect = frame
        }

        guard isUsableAnchor(rect) else { return nil }
        return rect
    }

    private func bestElementBounds(element: AXUIElement) -> CGRect? {
        var current: AXUIElement? = element
        var best: CGRect?

        for _ in 0..<5 {
            guard let candidate = current else { break }
            if let rect = focusedElementBounds(element: candidate),
               isTextEntryElement(candidate),
               isLikelyInputAnchor(rect) {
                return rect
            }
            if best == nil,
               let rect = focusedElementBounds(element: candidate),
               isLikelyInputAnchor(rect) {
                best = rect
            }

            var parentVal: CFTypeRef?
            guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parentVal) == .success,
                  let parent = parentVal
            else { break }
            current = (parent as! AXUIElement)
        }

        return best
    }

    private func textEntryBounds(from element: AXUIElement) -> CGRect? {
        var current: AXUIElement? = element

        for _ in 0..<7 {
            guard let candidate = current else { break }
            if let rect = focusedElementBounds(element: candidate), isLikelyInputAnchor(rect) {
                if isTextEntryElement(candidate) {
                    return rect
                }
            }

            var parentVal: CFTypeRef?
            guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parentVal) == .success,
                  let parent = parentVal
            else { break }
            current = (parent as! AXUIElement)
        }

        return nil
    }

    private func approximateTypingBounds(element: AXUIElement, typedLength: Int) -> CGRect? {
        guard let inputRect = bestElementBounds(element: element) ?? focusedElementBounds(element: element),
              isLikelyInputAnchor(inputRect)
        else { return nil }

        let lineHeight = min(max(inputRect.height * 0.55, 14), 22)
        let verticalInset = max((inputRect.height - lineHeight) / 2, 2)
        let horizontalInset: CGFloat = inputRect.height <= 28 ? 6 : 12
        let estimatedTextWidth = CGFloat(max(typedLength, 1)) * 7.2
        let x = min(max(inputRect.minX + horizontalInset + estimatedTextWidth, inputRect.minX + horizontalInset), inputRect.maxX - 8)
        let y = inputRect.minY + verticalInset
        return CGRect(x: x, y: y, width: 1, height: lineHeight)
    }

    private func screenBounds(element: AXUIElement, range: CFRange) -> CGRect? {
        var targetRange = range
        let param = AXValueCreate(.cfRange, &targetRange)!
        var boundsVal: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, "AXBoundsForRange" as CFString, param, &boundsVal) == .success
        else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsVal as! AXValue, .cgRect, &rect) else { return nil }
        guard rect.width.isFinite, rect.height.isFinite,
              rect.width >= 0, rect.height >= 0,
              rect.origin.x.isFinite, rect.origin.y.isFinite
        else { return nil }
        return rect
    }

    private func normalizedCaretRect(_ rect: CGRect) -> CGRect {
        var normalized = rect
        if normalized.width < 1 { normalized.size.width = 1 }
        if normalized.height < 1 { normalized.size.height = 14 }
        return normalized
    }

    private func focusedDescendant(of element: AXUIElement) -> AXUIElement? {
        var focusVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &focusVal) == .success,
              let focused = focusVal
        else { return nil }
        let focusedElement = focused as! AXUIElement
        guard !CFEqual(element, focusedElement) else { return nil }
        return focusedElement
    }

    private func firstTextEntryDescendant(of element: AXUIElement, maxDepth: Int) -> AXUIElement? {
        guard maxDepth > 0 else { return nil }
        var childrenVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
              let children = childrenVal as? [AXUIElement]
        else { return nil }

        for child in children.prefix(80) {
            if isTextEntryElement(child) {
                return child
            }
            if let nested = firstTextEntryDescendant(of: child, maxDepth: maxDepth - 1) {
                return nested
            }
        }
        return nil
    }

    private func isTextEntryElement(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(kAXRoleAttribute as String, element: element)
        let subrole = stringAttribute(kAXSubroleAttribute as String, element: element)
        let textRoles = ["AXTextArea", "AXTextField", "AXComboBox"]
        if let role, textRoles.contains(role) { return true }
        if subrole == "AXSearchField" { return true }
        if hasAttribute("AXSelectedTextRange", element: element)
            || hasAttribute("AXSelectedTextMarkerRange", element: element) {
            return true
        }
        if hasAttribute("AXEditableAncestor", element: element) {
            return true
        }
        return textEntryHint(in: element)
    }

    private func textEntryHint(in element: AXUIElement) -> Bool {
        let fields = [
            stringAttribute(kAXTitleAttribute as String, element: element),
            stringAttribute(kAXDescriptionAttribute as String, element: element),
            stringAttribute(kAXValueAttribute as String, element: element),
            stringAttribute(kAXHelpAttribute as String, element: element),
            stringAttribute("AXPlaceholderValue", element: element)
        ]

        let text = fields.compactMap { $0 }.joined(separator: " ").lowercased()
        guard !text.isEmpty else { return false }

        let hints = [
            "nhập", "tin nhắn tới", "tìm kiếm",
            "message", "type", "write", "reply", "comment", "search"
        ]
        if hints.contains(where: { text.contains($0) }) {
            return true
        }
        return false
    }

    private func recentAnchorBounds() -> CGRect? {
        guard let recentInputAnchor,
              Date().timeIntervalSince(recentInputAnchor.timestamp) <= Self.recentAnchorLifetime,
              let focusedApp = focusedApplication(),
              processID(of: focusedApp) == recentInputAnchor.appPID
        else { return nil }
        return recentInputAnchor.rect
    }

    private func processID(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    private func stringAttribute(_ attribute: String, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func hasAttribute(_ attribute: String, element: AXUIElement) -> Bool {
        var namesVal: CFArray?
        guard AXUIElementCopyAttributeNames(element, &namesVal) == .success,
              let names = namesVal as? [String]
        else { return false }
        return names.contains(attribute)
    }

    private func isUsableAnchor(_ rect: CGRect) -> Bool {
        rect.width.isFinite && rect.height.isFinite
            && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width >= 1 && rect.height >= 1
            && rect.width < 2400 && rect.height < 1200
    }

    private func isLikelyInputAnchor(_ rect: CGRect) -> Bool {
        isUsableAnchor(rect)
            && rect.width >= 40
            && rect.height >= 18
            && rect.height <= 180
    }
}
