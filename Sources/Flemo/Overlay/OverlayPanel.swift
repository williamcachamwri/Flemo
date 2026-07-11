import Cocoa
import SwiftUI

class OverlayPanel: NSPanel {
    init<V: View>(contentView: NSHostingView<V>) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.worksWhenModal = true
        self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.isOpaque = false
        contentView.layer?.masksToBounds = false
        contentView.enclosingScrollView?.drawsBackground = false
        self.contentView = contentView
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView?.layer?.isOpaque = false
    }

    func show(at axPoint: NSPoint) {
        show(below: CGRect(origin: axPoint, size: CGSize(width: 1, height: 1)))
    }

    func show(below axRect: CGRect) {
        let contentSize = fittingContentSize()
        let panelWidth = contentSize.width
        let panelHeight = contentSize.height
        let gap = max(3, min(5, panelHeight * 0.08))
        let horizontalNudge: CGFloat = -4

        guard let anchor = cocoaRect(fromAXRect: axRect),
              let screen = screen(containingCocoaPoint: NSPoint(x: anchor.midX, y: anchor.midY))
                ?? NSScreen.main
                ?? NSScreen.screens.first
        else { return }

        var x = anchor.minX + horizontalNudge
        var y = anchor.minY - panelHeight - gap

        let vf = screen.visibleFrame
        if x + panelWidth > vf.maxX { x = vf.maxX - panelWidth - 10 }
        if x < vf.minX { x = vf.minX + 10 }
        if y < vf.minY { y = anchor.maxY + gap }
        if y + panelHeight > vf.maxY { y = vf.maxY - panelHeight - 10 }
        if y < vf.minY { y = vf.minY + 10 }

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        displayIfNeeded()
        setIsVisible(true)
        orderFrontRegardless()
    }

    private func fittingContentSize() -> CGSize {
        contentView?.layoutSubtreeIfNeeded()
        let size = contentView?.fittingSize ?? .zero
        if size.width.isFinite, size.height.isFinite,
           size.width > 0, size.height > 0 {
            return size
        }
        return CGSize(width: 254, height: 62)
    }

    private func cocoaRect(fromAXRect axRect: CGRect) -> CGRect? {
        let probe = CGPoint(x: axRect.midX, y: axRect.midY)
        let screen = screen(containingAXPoint: probe) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen, let displayBounds = cgDisplayBounds(for: screen) else { return nil }

        let width = max(axRect.width, 1)
        let height = max(axRect.height, 1)
        let x = screen.frame.minX + (axRect.minX - displayBounds.minX)
        let y = screen.frame.maxY - ((axRect.minY - displayBounds.minY) + height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func screen(containingAXPoint point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let bounds = cgDisplayBounds(for: screen) else { return false }
            return bounds.contains(point)
        }
    }

    private func screen(containingCocoaPoint point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func cgDisplayBounds(for screen: NSScreen) -> CGRect? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
    }

    func hide() {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
