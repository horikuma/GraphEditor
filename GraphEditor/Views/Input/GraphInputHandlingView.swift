import AppKit
import SwiftUI

struct GraphInputHandlingView: NSViewRepresentable {
    let focusRequest: Int
    let onKeyDown: (NSEvent) -> Bool
    let onScroll: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(focusRequest: focusRequest)
    }

    func makeNSView(context: Context) -> GraphInputNSView {
        let view = GraphInputNSView()
        view.onKeyDown = onKeyDown
        view.onScroll = onScroll

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: GraphInputNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.onScroll = onScroll

        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest

            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class Coordinator {
        var focusRequest: Int

        init(focusRequest: Int) {
            self.focusRequest = focusRequest
        }
    }
}

final class GraphInputNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onScroll: ((CGSize) -> Void)?
    private var scrollMonitor: Any?

    deinit {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateScrollMonitor()
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }

        super.keyDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        handleScrollWheel(event)
    }

    private func updateScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }

        guard window != nil else {
            return
        }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.contains(event) else {
                return event
            }

            self.handleScrollWheel(event)
            return nil
        }
    }

    private func contains(_ event: NSEvent) -> Bool {
        guard let window, event.window === window else {
            return false
        }

        let location = convert(event.locationInWindow, from: nil)
        return bounds.contains(location)
    }

    private func handleScrollWheel(_ event: NSEvent) {
        let delta = CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY)
        guard delta != .zero else {
            super.scrollWheel(with: event)
            return
        }

        onScroll?(delta)
    }
}
