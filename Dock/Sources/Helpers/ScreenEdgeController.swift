//
//  ScreenEdgeController.swift
//  Dock
//
//  Created by Pierluigi Galdi on 15/11/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import AppKit

internal protocol ScreenEdgeDelegate {
	func screenEdgeController(_ controller: ScreenEdgeController, mouseMovedAtLocation location: NSPoint?)
	func screenEdgeController(_ controller: ScreenEdgeController, mouseClickAtLocation location: NSPoint?)
}

internal class ScreenEdgeController: NSWindowController {
	
	/// Singleton
	internal static let shared: ScreenEdgeController = ScreenEdgeController.setup()
	
	/// Core
	private var trackingArea: NSTrackingArea?
	internal var delegate: ScreenEdgeDelegate?
	internal var contentSize: CGFloat = NSScreen.screens.first?.frame.width ?? 0 {
		didSet {
			snapToScreenBottomEdge()
		}
	}
	
	/// Data
	private var screenBottomEdgeRect: NSRect {
		return NSRect(x: window?.frame.origin.x ?? 0, y: 0, width: contentSize, height: 1)
	}
	
	/// Deinit
	deinit {
		NotificationCenter.default.removeObserver(self)
		if let trackingArea = trackingArea {
			window?.contentView?.removeTrackingArea(trackingArea)
		}
		window?.close()
	}
	
	/// Private initialiser
	private static func setup() -> ScreenEdgeController {
		/// Create tracking window
		let window: NSWindow? = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true, screen: nil)
		window?.collectionBehavior   = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
		window?.isReleasedWhenClosed = true
		window?.ignoresMouseEvents   = false
		window?.hidesOnDeactivate    = false
		window?.level 				 = .mainMenu
		window?.canHide 		     = false
		window?.animationBehavior    = .none
		window?.hasShadow  		= false
		window?.isOpaque   		= false
		window?.backgroundColor = .black
		window?.alphaValue 		= 0
		/// Create controller
		let controller = ScreenEdgeController(window: window)
		/// Register for notifications
		NotificationCenter.default.addObserver(controller, selector: #selector(screenChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
		/// Setup window
		window?.delegate = controller
		controller.snapToScreenBottomEdge()
		window?.orderFrontRegardless()
		/// Log
		print("[DockWidget]: Setup ScreenEdgeController: \(controller) || \(window?.debugDescription ?? "unknown-window")")
		/// Return controller
		return controller
	}
	
	/// Private methods
	@objc private func screenChanged(_ notification: NSNotification?) {
		print("[DockWidget] Screen changed: \(notification?.debugDescription ?? "")")
		// TODO: Implement
	}
	
	private func snapToScreenBottomEdge() {
		if let previousTrackingArea = trackingArea {
			window?.contentView?.removeTrackingArea(previousTrackingArea)
			trackingArea = nil
		}
		guard let window = window else {
			return
		}
		window.setFrame(screenBottomEdgeRect, display: true, animate: false)
		window.center()
		window.setFrame(screenBottomEdgeRect, display: true, animate: false)
		trackingArea = NSTrackingArea(rect: window.contentView?.bounds ?? screenBottomEdgeRect, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self, userInfo: nil)
		window.contentView?.addTrackingArea(trackingArea!)
	}
	
}

// MARK: NSWindowDelegate
extension ScreenEdgeController: NSWindowDelegate {
	
	/// Mouse did enter in edge window
	override func mouseEntered(with event: NSEvent) {
		NSCursor.hide()
		mouseMoved(with: event)
	}
	
	/// Did move mouse in edge window
	override func mouseMoved(with event: NSEvent) {
		guard let delegate = delegate, let point = window?.mouseLocationOutsideOfEventStream else {
			return
		}
		delegate.screenEdgeController(self, mouseMovedAtLocation: point)
	}
	
	/// Did click in edge window
	override func mouseUp(with event: NSEvent) {
		guard let delegate = delegate else {
			return
		}
		delegate.screenEdgeController(self, mouseClickAtLocation: event.locationInWindow)
	}
	
	/// Did scroll/swipe in edge window
	override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
		return axis == .horizontal
	}
	override func scrollWheel(with event: NSEvent) {
		print("[DockWidget]: Scroll WHEEL at: \(event.locationInWindow)")
	}
	
	/// Mouse did exit from edge window
	override func mouseExited(with event: NSEvent) {
		NSCursor.unhide()
		delegate?.screenEdgeController(self, mouseMovedAtLocation: nil)
	}
}
