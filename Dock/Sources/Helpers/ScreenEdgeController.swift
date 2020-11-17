//
//  ScreenEdgeController.swift
//  Dock
//
//  Created by Pierluigi Galdi on 15/11/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import AppKit

internal protocol ScreenEdgeDelegate: class {
	func screenEdgeController(_ controller: ScreenEdgeController, mouseMovedAtLocation location: NSPoint?)
	func screenEdgeController(_ controller: ScreenEdgeController, mouseClickAtLocation location: NSPoint)
	func screenEdgeController(_ controller: ScreenEdgeController, mouseScrollWithDelta delta: CGFloat)
}

internal class ScreenEdgeController: NSWindowController {
	
	/// Core
	private var trackingArea: NSTrackingArea?
	internal weak var delegate: ScreenEdgeDelegate?
	internal var contentSize: CGFloat = NSScreen.screens.first?.frame.width ?? 0 {
		didSet {
			snapToScreenBottomEdge()
		}
	}
	
	/// Data
	private var screenBottomEdgeRect: NSRect {
		return NSRect(x: window?.frame.origin.x ?? 0, y: 0, width: contentSize, height: 10)
	}
	
	/// Deinit
	deinit {
		tearDown()
	}
	
	/// Private initialiser
	internal convenience init(delegate: ScreenEdgeDelegate?) {
		/// Create tracking window
		let window: NSWindow? = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false, screen: NSScreen.main)
		window?.collectionBehavior   	  = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
		window?.isExcludedFromWindowsMenu = true
		window?.isReleasedWhenClosed 	  = true
		window?.acceptsMouseMovedEvents   = true
		window?.ignoresMouseEvents   	  = false
		window?.hidesOnDeactivate    	  = false
		window?.canHide 		     	  = false
		window?.level 				 	  = .screenSaver
		window?.animationBehavior    	  = .none
		window?.hasShadow  				  = false
		window?.isOpaque   				  = false
		window?.backgroundColor 		  = .red
		window?.alphaValue 				  = 1
		/// Create controller
		self.init(window: window)
		self.delegate = delegate
		/// Register for notifications
		NotificationCenter.default.addObserver(self, selector: #selector(screenChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
		/// Setup window
		window?.orderFrontRegardless()
		window?.delegate = self
		self.snapToScreenBottomEdge()
		/// Log
		print("[DockWidget]: Setup ScreenEdgeController...")
	}
	
	/// Tear down
	public func tearDown() {
		NotificationCenter.default.removeObserver(self)
		if let trackingArea = trackingArea {
			window?.contentView?.removeTrackingArea(trackingArea)
		}
		window?.close()
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
		window.centerHorizontally()
		trackingArea = NSTrackingArea(rect: window.contentView?.bounds ?? screenBottomEdgeRect, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self, userInfo: nil)
		window.contentView?.addTrackingArea(trackingArea!)
	}
	
}

// MARK: NSWindowDelegate
extension ScreenEdgeController: NSWindowDelegate {
	
	/// Mouse did enter in edge window
	override func mouseEntered(with event: NSEvent) {
		mouseMoved(with: event)
	}
	
	/// Did move mouse in edge window
	override func mouseMoved(with event: NSEvent) {
		guard let delegate = delegate, let point = window?.mouseLocationOutsideOfEventStream else {
			return
		}
		delegate.screenEdgeController(self, mouseMovedAtLocation: point)
	}
	
	/// Did scroll mouse in edge window
	override func scrollWheel(with event: NSEvent) {
		guard let delegate = delegate else {
			return
		}
		delegate.screenEdgeController(self, mouseScrollWithDelta: event.deltaX)
	}
	
	/// Did click in edge window
	override func mouseUp(with event: NSEvent) {
		guard let delegate = delegate else {
			return
		}
		delegate.screenEdgeController(self, mouseClickAtLocation: event.locationInWindow)
	}
	
	/// Mouse did exit from edge window
	override func mouseExited(with event: NSEvent) {
		delegate?.screenEdgeController(self, mouseMovedAtLocation: nil)
	}
}
