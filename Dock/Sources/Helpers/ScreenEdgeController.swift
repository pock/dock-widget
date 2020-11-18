//
//  ScreenEdgeController.swift
//  Dock
//
//  Created by Pierluigi Galdi on 15/11/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import AppKit

@objc public protocol ScreenEdgeMouseDelegate: class {
	/// Required
	func screenEdgeController(_ controller: ScreenEdgeController, mouseEnteredAtLocation location: NSPoint)
	func screenEdgeController(_ controller: ScreenEdgeController, mouseMovedAtLocation 	 location: NSPoint)
	func screenEdgeController(_ controller: ScreenEdgeController, mouseClickAtLocation 	 location: NSPoint)
	func screenEdgeController(_ controller: ScreenEdgeController, mouseExitedAtLocation  location: NSPoint)
	func screenEdgeController(_ controller: ScreenEdgeController, draggingEntered 	   info: NSDraggingInfo, filepath: String) -> NSDragOperation
	func screenEdgeController(_ controller: ScreenEdgeController, draggingUpdated 	   info: NSDraggingInfo, filepath: String) -> NSDragOperation
	func screenEdgeController(_ controller: ScreenEdgeController, performDragOperation info: NSDraggingInfo, filepath: String) -> Bool
	func screenEdgeController(_ controller: ScreenEdgeController, draggingEnded 	   info: NSDraggingInfo)
	/// Optionals
	@objc optional func screenEdgeController(_ controller: ScreenEdgeController, mouseScrollWithDelta delta: CGFloat, atLocation location: NSPoint)
}

@objc public class ScreenEdgeController: NSWindowController {
	
	/// Core
	private var trackingArea: NSTrackingArea?
	internal var contentSize: CGFloat = NSScreen.screens.first?.frame.width ?? 0 {
		didSet {
			snapToScreenBottomEdge()
		}
	}
	
	/// Delegates
	internal weak var mouseDelegate: ScreenEdgeMouseDelegate?
	
	/// Data
	private var screenBottomEdgeRect: NSRect {
		return NSRect(x: window?.frame.origin.x ?? 0, y: 0, width: contentSize, height: 10)
	}
	
	/// Deinit
	deinit {
		tearDown()
	}
	
	/// Private initialiser
	internal convenience init(mouseDelegate: ScreenEdgeMouseDelegate?) {
		/// Create tracking window
		let window: NSWindow? = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false, screen: NSScreen.main)
		window?.collectionBehavior   	  = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
		window?.isExcludedFromWindowsMenu = true
		window?.isReleasedWhenClosed 	  = true
		window?.ignoresMouseEvents   	  = false
		window?.hidesOnDeactivate    	  = false
		window?.canHide 		     	  = false
		window?.level 				 	  = .mainMenu
		window?.animationBehavior    	  = .none
		window?.hasShadow  				  = false
		window?.isOpaque   				  = false
		window?.backgroundColor 		  = .red
		window?.alphaValue 				  = 0
		/// Dragging support
		window?.registerForDraggedTypes([.URL, .fileURL, .filePromise])
		/// Create controller
		self.init(window: window)
		self.mouseDelegate = mouseDelegate
		/// Setup window
		window?.orderFrontRegardless()
		window?.delegate = self
		self.snapToScreenBottomEdge()
		/// Log
		print("[DockWidget]: Setup ScreenEdgeController...")
	}
	
	/// Tear down
	public func tearDown() {
		if let trackingArea = trackingArea {
			window?.contentView?.removeTrackingArea(trackingArea)
		}
		window?.close()
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

// MARK: Mouse Delegate
extension ScreenEdgeController: NSWindowDelegate {
	
	/// Mouse did enter in edge window
	override public func mouseEntered(with event: NSEvent) {
		guard let delegate = mouseDelegate, let point = window?.mouseLocationOutsideOfEventStream else {
			return
		}
		delegate.screenEdgeController(self, mouseEnteredAtLocation: point)
	}
	
	/// Did move mouse in edge window
	override public func mouseMoved(with event: NSEvent) {
		guard let delegate = mouseDelegate, let point = window?.mouseLocationOutsideOfEventStream else {
			return
		}
		delegate.screenEdgeController(self, mouseMovedAtLocation: point)
	}
	
	/// Did scroll mouse in edge window
	override public func scrollWheel(with event: NSEvent) {
		guard let delegate = mouseDelegate else {
			return
		}
		delegate.screenEdgeController?(self, mouseScrollWithDelta: event.deltaX, atLocation: event.locationInWindow)
	}
	
	/// Did click in edge window
	override public func mouseUp(with event: NSEvent) {
		guard let delegate = mouseDelegate else {
			return
		}
		delegate.screenEdgeController(self, mouseClickAtLocation: event.locationInWindow)
	}
	
	/// Mouse did exit from edge window
	override public func mouseExited(with event: NSEvent) {
		mouseDelegate?.screenEdgeController(self, mouseExitedAtLocation: event.locationInWindow)
	}

}

// MARK: Dragging Delegate
extension ScreenEdgeController: NSDraggingDestination {
	
	public func wantsPeriodicDraggingUpdates() -> Bool {
		return false
	}
	
	public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
		guard let delegate = mouseDelegate,
			  let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
			  let path = pasteboard[0] as? String else {
			return NSDragOperation()
		}
		return delegate.screenEdgeController(self, draggingEntered: sender, filepath: path)
	}
	
	public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
		guard let delegate = mouseDelegate,
			  let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
			  let path = pasteboard[0] as? String else {
			return NSDragOperation()
		}
		return delegate.screenEdgeController(self, draggingUpdated: sender, filepath: path)
	}
	
	public func draggingExited(_ sender: NSDraggingInfo?) {
		guard let delegate = mouseDelegate, let location = sender?.draggingLocation ?? window?.mouseLocationOutsideOfEventStream else {
			return
		}
		delegate.screenEdgeController(self, mouseExitedAtLocation: location)
	}
	
	public func draggingEnded(_ sender: NSDraggingInfo) {
		guard let delegate = mouseDelegate else {
			return
		}
		delegate.screenEdgeController(self, draggingEnded: sender)
	}
	
	public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		guard let delegate = mouseDelegate,
			  let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
			  let path = pasteboard[0] as? String else {
			return false
		}
		return delegate.screenEdgeController(self, performDragOperation: sender, filepath: path)
	}
	
}
