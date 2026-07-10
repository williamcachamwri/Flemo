import Cocoa
import os.log

struct TextContext {
    let textBeforeCursor: String
    let cursorScreenPosition: NSPoint
    let cursorScreenBounds: CGRect
    let focusedElementBounds: CGRect
}

struct TypingAnchorBounds {
    enum CoordinateSpace {
        case accessibility
        case cocoa
    }

    let rect: CGRect
    let coordinateSpace: CoordinateSpace
}

class TextContextProvider {
    static let shared = TextContextProvider()
    private let log = OSLog(subsystem: "com.flemo.app", category: "TextCtx")
    private static let maxContextLength = 100
    private static let recentAnchorLifetime: TimeInterval = 45
    private static let recentInteractionLifetime: TimeInterval = 120

    private struct RecentInputAnchor {
        let rect: CGRect
        let appPID: pid_t
        let timestamp: Date
    }

    private struct RecentInteractionAnchor {
        let axPoint: CGPoint
        let cocoaPoint: CGPoint
        let appPID: pid_t
        let windowRect: CGRect?
        let timestamp: Date
    }

    private struct TextEntryCandidate {
        let rect: CGRect
        let score: Int
    }

    private var recentInputAnchor: RecentInputAnchor?
    private var recentInteractionAnchor: RecentInteractionAnchor?

    @discardableResult
    func rememberPotentialInputAnchor(at point: CGPoint, cocoaPoint: CGPoint) -> Bool {
        if isPointInsideOwnVisibleWindow(cocoaPoint) {
            return false
        }

        guard let appPID = activeProcessID() else { return false }

        let app = focusedApplication()
        let windowRect = app
            .flatMap { focusedWindowElement(of: $0) ?? primaryWindowElement(of: $0) }
            .flatMap { focusedElementBounds(element: $0) }
        recentInteractionAnchor = RecentInteractionAnchor(
            axPoint: point,
            cocoaPoint: cocoaPoint,
            appPID: appPID,
            windowRect: windowRect,
            timestamp: Date()
        )

        guard let app else { return true }
        var hitElement: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hitElement) == .success,
              let hitElement
        else { return false }

        guard let rect = textEntryBounds(from: hitElement)
            ?? bestTextEntryDescendantBounds(of: hitElement, maxDepth: 5, containerBounds: nil)
        else { return false }

        recentInputAnchor = RecentInputAnchor(rect: rect, appPID: appPID, timestamp: Date())
        return true
    }

    func currentQuickEmojiAnchor() -> TypingAnchorBounds? {
        if let clickRect = recentInteractionCocoaAnchorBounds(maxAge: Self.recentInteractionLifetime) {
            os_log(.debug, log: log, "Quick anchor source=click-cocoa x=%.1f y=%.1f", Double(clickRect.minX), Double(clickRect.minY))
            return TypingAnchorBounds(rect: clickRect, coordinateSpace: .cocoa)
        }

        if let axRect = currentTypingAnchorBounds() {
            os_log(.debug, log: log, "Quick anchor source=ax x=%.1f y=%.1f", Double(axRect.minX), Double(axRect.minY))
            return TypingAnchorBounds(rect: axRect, coordinateSpace: .accessibility)
        }

        os_log(.debug, log: log, "Quick anchor source=none")
        return nil
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
                return triggerAnchorRect(from: textRect, typedLength: boundedLength, element: element)
            }
        }

        if let markerRect = selectedTextMarkerBounds(element: element),
           isUsableAnchor(markerRect) {
            return triggerAnchorRect(from: markerRect, typedLength: length, element: element)
        }

        guard let cursor = selectedCursor(in: element) else {
            return approximateTypingBounds(element: element, typedLength: length)
                ?? bestElementBounds(element: element)
                ?? recentAnchorBounds()
        }

        if let cursorRect = cursorScreenBounds(element: element, cursor: cursor),
           isUsableAnchor(cursorRect) {
            return triggerAnchorRect(from: cursorRect, typedLength: length, element: element)
        }

        if let approximateRect = approximateTypingBounds(element: element, typedLength: length) {
            return approximateRect
        }

        return bestElementBounds(element: element)
            ?? recentAnchorBounds()
    }

    func currentTypingAnchorBounds() -> CGRect? {
        guard let element = textInputElement() else {
            if let recent = recentAnchorBounds() {
                return insertionAnchorRect(in: recent)
            }
            if let descendant = focusedTextEntryDescendantAnchor() {
                return insertionAnchorRect(in: descendant)
            }
            if let interaction = recentInteractionAnchorBounds() {
                return interaction
            }
            return nil
        }

        if let markerRect = selectedTextMarkerBounds(element: element),
           isUsableAnchor(markerRect) {
            return preferredCurrentAnchor(from: triggerAnchorRect(from: markerRect, typedLength: 0, element: element))
        }

        if let cursor = selectedCursor(in: element),
           let cursorRect = cursorScreenBounds(element: element, cursor: cursor),
           isUsableAnchor(cursorRect) {
            return preferredCurrentAnchor(from: triggerAnchorRect(from: cursorRect, typedLength: 0, element: element))
        }

        if let context = getTextContext(),
           isUsableAnchor(context.cursorScreenBounds) {
            return preferredCurrentAnchor(from: context.cursorScreenBounds)
        }

        if let recent = recentAnchorBounds() {
            return insertionAnchorRect(in: recent)
        }

        if let descendant = focusedTextEntryDescendantAnchor() {
            return insertionAnchorRect(in: descendant)
        }

        if let interaction = recentInteractionAnchorBounds() {
            return interaction
        }

        if let inputRect = bestElementBounds(element: element) ?? focusedElementBounds(element: element),
           isLikelyInputAnchor(inputRect) {
            return insertionAnchorRect(in: inputRect)
        }

        return nil
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

    private func focusedTextEntryDescendantAnchor() -> CGRect? {
        guard let app = focusedApplication() else { return nil }

        if let window = focusedWindowElement(of: app) ?? primaryWindowElement(of: app) {
            let windowBounds = focusedElementBounds(element: window)
            if let rect = bestTextEntryDescendantBounds(
                of: window,
                maxDepth: 9,
                containerBounds: windowBounds
            ) {
                return rect
            }
        }

        if let focus = focusedElement(),
           let rect = bestTextEntryDescendantBounds(of: focus, maxDepth: 7, containerBounds: focusedElementBounds(element: focus)) {
            return rect
        }

        return bestTextEntryDescendantBounds(of: app, maxDepth: 9, containerBounds: focusedElementBounds(element: app))
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
        let horizontalInset = horizontalTextInset(for: inputRect)
        let estimatedTextWidth = estimatedTriggerWidth(characterCount: typedLength, lineHeight: lineHeight)
        let x = min(max(inputRect.minX + horizontalInset, inputRect.minX + 2), inputRect.maxX - 8)
        let y = inputRect.minY + verticalInset
        return CGRect(x: x, y: y, width: estimatedTextWidth, height: lineHeight)
    }

    private func insertionAnchorRect(in inputRect: CGRect) -> CGRect {
        let lineHeight = min(max(inputRect.height * 0.22, 16), 24)
        let horizontalInset = inputRect.height >= 64
            ? min(max(inputRect.width * 0.018, 22), 34)
            : horizontalTextInset(for: inputRect)
        let verticalInset = inputRect.height >= 64
            ? min(max(inputRect.height * 0.18, 18), 36)
            : max((inputRect.height - lineHeight) / 2, 2)
        let x = min(max(inputRect.minX + horizontalInset, inputRect.minX + 2), inputRect.maxX - 8)
        let y = min(max(inputRect.minY + verticalInset, inputRect.minY + 2), inputRect.maxY - lineHeight)
        return CGRect(x: x, y: y, width: 2, height: lineHeight)
    }

    private func preferredCurrentAnchor(from exactRect: CGRect) -> CGRect {
        if let recent = recentAnchorBounds(),
           shouldPreferInputAnchor(recent, over: exactRect) {
            return insertionAnchorRect(in: recent)
        }

        if let descendant = focusedTextEntryDescendantAnchor(),
           shouldPreferInputAnchor(descendant, over: exactRect) {
            return insertionAnchorRect(in: descendant)
        }

        if let interaction = recentInteractionAnchorBounds(),
           shouldPreferInteractionAnchor(interaction, over: exactRect) {
            return interaction
        }

        return exactRect
    }

    private func shouldPreferInputAnchor(_ inputRect: CGRect, over exactRect: CGRect) -> Bool {
        guard isLikelyInputAnchor(inputRect), isUsableAnchor(exactRect) else { return false }
        guard !isPlausibleCaretRect(exactRect) else { return false }

        let expandedInput = inputRect.insetBy(dx: -36, dy: -48)
        if expandedInput.intersects(exactRect) {
            return false
        }

        if exactRect.width > 24 || exactRect.height > 72 {
            return true
        }

        let verticalDistance = abs(exactRect.midY - inputRect.midY)
        return verticalDistance > max(inputRect.height * 0.65, 90)
    }

    private func shouldPreferInteractionAnchor(_ interactionRect: CGRect, over exactRect: CGRect) -> Bool {
        guard isUsableAnchor(exactRect) else { return true }
        guard !isPlausibleCaretRect(exactRect) else { return false }
        let expandedInteraction = interactionRect.insetBy(dx: -48, dy: -56)
        if expandedInteraction.intersects(exactRect) {
            return false
        }
        return abs(exactRect.midY - interactionRect.midY) > 120
    }

    private func isPlausibleCaretRect(_ rect: CGRect) -> Bool {
        rect.width <= 24 && rect.height <= 72
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

    private func triggerAnchorRect(from rect: CGRect, typedLength: Int, element: AXUIElement) -> CGRect {
        guard typedLength > 0 else { return rect }

        let estimatedWidth = estimatedTriggerWidth(characterCount: typedLength, lineHeight: rect.height)
        guard rect.width <= max(4, estimatedWidth * 0.55) else {
            return rect
        }

        var x = rect.maxX - estimatedWidth
        if let inputRect = bestElementBounds(element: element) ?? focusedElementBounds(element: element),
           isLikelyInputAnchor(inputRect) {
            let minimumX = inputRect.minX + horizontalTextInset(for: inputRect)
            let maximumX = inputRect.maxX - 8
            x = min(max(x, minimumX), maximumX)
        }

        return CGRect(
            x: x,
            y: rect.minY,
            width: max(estimatedWidth, 1),
            height: max(rect.height, 14)
        )
    }

    private func estimatedTriggerWidth(characterCount: Int, lineHeight: CGFloat) -> CGFloat {
        let glyphWidth = min(max(lineHeight * 0.55, 7.2), 13.5)
        return CGFloat(max(characterCount, 1)) * glyphWidth
    }

    private func horizontalTextInset(for rect: CGRect) -> CGFloat {
        rect.height <= 28 ? 6 : 12
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

    private func focusedWindowElement(of app: AXUIElement) -> AXUIElement? {
        var windowVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowVal) == .success,
              let windowVal
        else { return nil }
        return (windowVal as! AXUIElement)
    }

    private func primaryWindowElement(of app: AXUIElement) -> AXUIElement? {
        var windowsVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsVal) == .success,
              let windows = windowsVal as? [AXUIElement]
        else { return nil }
        return windows.first
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

    private func bestTextEntryDescendantBounds(
        of element: AXUIElement,
        maxDepth: Int,
        containerBounds: CGRect?
    ) -> CGRect? {
        guard maxDepth > 0 else { return nil }
        var candidates: [TextEntryCandidate] = []
        collectTextEntryDescendantBounds(
            of: element,
            maxDepth: maxDepth,
            containerBounds: containerBounds,
            into: &candidates
        )
        let lowerHalfCandidates = candidates.filter { candidate in
            guard let containerBounds else { return false }
            return candidate.rect.midY >= containerBounds.midY
        }
        let ranked = lowerHalfCandidates.isEmpty ? candidates : lowerHalfCandidates

        return ranked.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            if abs(lhs.rect.maxY - rhs.rect.maxY) > 8 {
                return lhs.rect.maxY > rhs.rect.maxY
            }
            if abs(lhs.rect.height - rhs.rect.height) > 6 {
                return lhs.rect.height < rhs.rect.height
            }
            return lhs.rect.width > rhs.rect.width
        }.first?.rect
    }

    private func collectTextEntryDescendantBounds(
        of element: AXUIElement,
        maxDepth: Int,
        containerBounds: CGRect?,
        into candidates: inout [TextEntryCandidate]
    ) {
        guard maxDepth > 0 else { return }

        if let rect = focusedElementBounds(element: element),
           isLikelyInputAnchor(rect) {
            let score = textEntryCandidateScore(element: element, rect: rect, containerBounds: containerBounds)
            if score > 0 {
                candidates.append(TextEntryCandidate(rect: rect, score: score))
            }
        }

        var childrenVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
              let children = childrenVal as? [AXUIElement]
        else { return }

        for child in children.prefix(220) {
            collectTextEntryDescendantBounds(
                of: child,
                maxDepth: maxDepth - 1,
                containerBounds: containerBounds,
                into: &candidates
            )
        }
    }

    private func textEntryCandidateScore(
        element: AXUIElement,
        rect: CGRect,
        containerBounds: CGRect?
    ) -> Int {
        var score = 0

        if isTextEntryElement(element) { score += 60 }
        let hintScore = textEntryHintScore(in: element)
        score += hintScore

        if rect.width >= 220 { score += 10 }
        if rect.width >= 420 { score += 10 }
        if rect.height >= 36 && rect.height <= 170 { score += 14 }
        if rect.height > 210 { score -= 12 }

        if let containerBounds {
            let relativeMidY = (rect.midY - containerBounds.minY) / max(containerBounds.height, 1)
            if relativeMidY >= 0.55 { score += 16 }
            if relativeMidY >= 0.72 { score += 20 }
            if relativeMidY >= 0.86 { score += 16 }
            if rect.maxY > containerBounds.maxY - 260 { score += 16 }
            if rect.width > containerBounds.width * 0.42 { score += 8 }
            if rect.height > containerBounds.height * 0.45 { score -= 40 }
        }

        if isLikelyComposeInput(rect, containerBounds: containerBounds) {
            score += 28
        }

        if hintScore < 0 { score -= 70 }
        if !isTextEntryElement(element), hintScore == 0, !isLikelyComposeInput(rect, containerBounds: containerBounds) {
            score -= 80
        }

        return score
    }

    private func textEntryHintScore(in element: AXUIElement) -> Int {
        let fields = [
            stringAttribute(kAXTitleAttribute as String, element: element),
            stringAttribute(kAXDescriptionAttribute as String, element: element),
            stringAttribute(kAXValueAttribute as String, element: element),
            stringAttribute(kAXHelpAttribute as String, element: element),
            stringAttribute("AXPlaceholderValue", element: element)
        ]

        let text = fields.compactMap { $0 }.joined(separator: " ").lowercased()
        guard !text.isEmpty else { return 0 }

        let composeHints = [
            "yêu cầu", "yeu cau", "thay đổi", "thay doi", "tiếp theo", "tiep theo",
            "nhập", "nhap", "tin nhắn", "tin nhan", "message", "prompt",
            "reply", "ask", "type", "write", "comment"
        ]
        let searchHints = ["search", "tìm kiếm", "tim kiem", "find"]

        if searchHints.contains(where: { text.contains($0) }) {
            return -1
        }
        return composeHints.contains(where: { text.contains($0) }) ? 58 : 0
    }

    private func isLikelyComposeInput(_ rect: CGRect, containerBounds: CGRect?) -> Bool {
        guard isUsableAnchor(rect),
              rect.width >= 220,
              rect.height >= 36,
              rect.height <= 230
        else { return false }

        guard let containerBounds else { return true }
        let relativeMidY = (rect.midY - containerBounds.minY) / max(containerBounds.height, 1)
        return relativeMidY >= 0.58 && rect.maxY >= containerBounds.maxY - 340
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
        return textEntryHintScore(in: element) > 0
    }

    private func recentAnchorBounds() -> CGRect? {
        guard let recentInputAnchor,
              Date().timeIntervalSince(recentInputAnchor.timestamp) <= Self.recentAnchorLifetime,
              activeProcessID() == recentInputAnchor.appPID
        else { return nil }
        return recentInputAnchor.rect
    }

    private func recentInteractionAnchorBounds() -> CGRect? {
        recentInteractionAnchorBounds(maxAge: Self.recentInteractionLifetime)
    }

    private func recentInteractionAnchorBounds(maxAge: TimeInterval) -> CGRect? {
        guard let recentInteractionAnchor,
              Date().timeIntervalSince(recentInteractionAnchor.timestamp) <= maxAge,
              activeProcessID() == recentInteractionAnchor.appPID
        else { return nil }

        if let windowRect = recentInteractionAnchor.windowRect {
            let relaxedWindow = windowRect.insetBy(dx: -24, dy: -24)
            guard relaxedWindow.contains(recentInteractionAnchor.axPoint)
            else { return nil }
        }

        return CGRect(
            x: recentInteractionAnchor.axPoint.x,
            y: recentInteractionAnchor.axPoint.y - 10,
            width: 2,
            height: 20
        )
    }

    private func recentInteractionCocoaAnchorBounds(maxAge: TimeInterval) -> CGRect? {
        guard let recentInteractionAnchor,
              Date().timeIntervalSince(recentInteractionAnchor.timestamp) <= maxAge,
              activeProcessID() == recentInteractionAnchor.appPID
        else { return nil }

        let point = recentInteractionAnchor.cocoaPoint
        guard NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -24, dy: -24).contains(point) })
        else { return nil }

        return CGRect(x: point.x, y: point.y - 10, width: 2, height: 20)
    }

    private func activeProcessID() -> pid_t? {
        if let focusedApp = focusedApplication(),
           let pid = processID(of: focusedApp) {
            return pid
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    private func isPointInsideOwnVisibleWindow(_ point: CGPoint) -> Bool {
        NSApp.windows.contains { window in
            window.isVisible && window.frame.insetBy(dx: -6, dy: -6).contains(point)
        }
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
            && rect.height <= 280
    }
}
