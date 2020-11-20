//
//  ScreenEdgeBaseController.swift
//  Dock
//
//  Created by Pierluigi Galdi on 20/11/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import AppKit
import PockKit

open class ScreenEdgeBaseController: NSObject, ScreenEdgeMouseDelegate {
	
	/// Core
	public private(set) var edgeController: ScreenEdgeController?
	
	/// The total content size width for the edge window
	open var totalContentSizeWidth: CGFloat {
		return 0
	}
	
	/// Default initialiser
	override init() {
		super.init()
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reloadScreenEdgeController), name: .shouldReloadScreenEdgeController, object: nil)
		self.reloadScreenEdgeController()
	}
	
	deinit {
		edgeController = nil
		NSWorkspace.shared.notificationCenter.removeObserver(self)
	}
	
	/// Re-create `edgeController` object
	@objc open func reloadScreenEdgeController() {
		self.edgeController = ScreenEdgeController(mouseDelegate: self)
		self.edgeController?.contentSize = self.totalContentSizeWidth
	}
	
	/// Mouse entered at location
	open func screenEdgeController(_ controller: ScreenEdgeController, mouseEnteredAtLocation location: NSPoint) {
		fatalError("Must be override in subclass")
	}
	
	/// Mouse did move at location
	open func screenEdgeController(_ controller: ScreenEdgeController, mouseMovedAtLocation location: NSPoint) {
		fatalError("Must be override in subclass")
	}
	
	/// Mouse did scroll with delta at location
	///
	/// This function is optional
	open func screenEdgeController(_ controller: ScreenEdgeController, mouseScrollWithDelta delta: CGFloat, atLocation location: NSPoint) {
		/// nothing to do here
	}
	
	/// Mouse clicked at location
	open func screenEdgeController(_ controller: ScreenEdgeController, mouseClickAtLocation location: NSPoint) {
		fatalError("Must be override in subclass")
	}
	
	/// Mouse exited at location
	open func screenEdgeController(_ controller: ScreenEdgeController, mouseExitedAtLocation location: NSPoint) {
		fatalError("Must be override in subclass")
	}
	
	/// Dragging entered with info for file at path
	open func screenEdgeController(_ controller: ScreenEdgeController, draggingEntered info: NSDraggingInfo, filepath: String) -> NSDragOperation {
		fatalError("Must be override in subclass")
	}
	
	/// Dragging updated with info for file at path
	open func screenEdgeController(_ controller: ScreenEdgeController, draggingUpdated info: NSDraggingInfo, filepath: String) -> NSDragOperation {
		fatalError("Must be override in subclass")
	}
	
	/// Dragging perform operation info for file at path
	open func screenEdgeController(_ controller: ScreenEdgeController, performDragOperation info: NSDraggingInfo, filepath: String) -> Bool {
		fatalError("Must be override in subclass")
	}
	
	/// Dragging ended with info
	open func screenEdgeController(_ controller: ScreenEdgeController, draggingEnded info: NSDraggingInfo) {
		fatalError("Must be override in subclass")
	}
	
}
