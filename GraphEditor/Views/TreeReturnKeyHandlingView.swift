import AppKit
import SwiftUI

struct TreeReturnKeyHandlingView: NSViewRepresentable {
    let onReturnKeyDown: () -> Void

    func makeNSView(context: Context) -> TreeReturnKeyNSView {
        let view = TreeReturnKeyNSView()
        view.onReturnKeyDown = onReturnKeyDown
        return view
    }

    func updateNSView(_ nsView: TreeReturnKeyNSView, context: Context) {
        nsView.onReturnKeyDown = onReturnKeyDown
    }
}

final class TreeReturnKeyNSView: NSView {
    var onReturnKeyDown: (() -> Void)?
    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateEventMonitor()
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    private func updateEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.shouldHandle(event)
            else {
                return event
            }

            self.onReturnKeyDown?()
            return nil
        }
    }

    private func shouldHandle(_ event: NSEvent) -> Bool {
        guard event.window === window, event.keyCode == 36 || event.keyCode == 76 else {
            return false
        }

        guard let focusedView = event.window?.firstResponder as? NSView else {
            return false
        }

        return focusedView.hasAncestor { view in
            view is NSTableView || view is NSOutlineView
        }
    }
}

private extension NSView {
    func hasAncestor(matching predicate: (NSView) -> Bool) -> Bool {
        var view: NSView? = self
        while let currentView = view {
            if predicate(currentView) {
                return true
            }
            view = currentView.superview
        }

        return false
    }
}
