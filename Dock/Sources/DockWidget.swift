//
//  DockWidget.swift
//  Pock
//
//  Created by Pierluigi Galdi on 06/04/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import PockKit
import TinyConstraints

class DockWidget: NSObject, PKWidget, PKScreenEdgeMouseDelegate {
	
	static var identifier: String = "DockWidget"
	var customizationLabel: String = "Dock"
	var view: NSView!
	
	/// Core
	private var dockRepository: 	  DockRepository!
	private var dropDispatchWorkItem: DispatchWorkItem?
	
	/// UI
	private var stackView:          NSStackView! = NSStackView(frame: .zero)
	private var dockScrubber:       NSScrubber!  = NSScrubber(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
	private var separator:          NSView! 	 = NSView(frame:     NSRect(x: 0, y: 0, width: 1, 	height: 20))
	private var persistentScrubber: NSScrubber!  = NSScrubber(frame: NSRect(x: 0, y: 0, width: 50, 	height: 30))
	
	private var persistentScrubberWidthConstraint: NSLayoutConstraint {
		if let previous = persistentScrubber.constraints.first(where: { $0.identifier == "persistentScrubber.width" }) {
			return previous
		} else {
			let constraint = persistentScrubber.width(0)
			constraint.identifier = "persistentScrubber.width"
			constraint.isActive = true
			return constraint
		}
	}
	
	/// Data
	private var dockItems:       [DockItem] = []
	private var persistentItems: [DockItem] = []
	private var cachedDockItemViews: 	   [DockItemView] = []
	private var cachedPersistentItemViews: [DockItemView] = []
	private var itemViewWithMouseOver: 	  DockItemView?
	private var itemViewWithDraggingOver: DockItemView?
	
	var imageForCustomization: NSImage {
		return NSImage(named: NSImage.preferencesGeneralName)!
	}
	
	override required init() {
		super.init()
		self.configureStackView()
		self.view = stackView
	}
	
	func initialize() {
		self.configureStackView()
		self.configureDockScrubber()
		self.configureSeparator()
		self.configurePersistentScrubber()
		self.displayScrubbers()
		self.view = stackView
		self.dockRepository = DockRepository(delegate: self)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displayScrubbers),
														  name: .shouldReloadPersistentItems, object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reloadScrubbersLayout),
														  name: .shouldReloadScrubbersLayout, object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(deepReload(_:)),
														  name: .shouldReloadDock, object: nil)
		/// Hide System Dock if needed
		if let hideSystemDock: Bool = Preferences[.hideSystemDock] {
			if hideSystemDock && DockHelper.currentMode == .visible {
				DockHelper.setDockMode(.hidden)
			}
		}else {
			if DockHelper.currentMode == .disabled {
				Preferences[.hideSystemDock] = true
				DockHelper.setDockMode(.hidden)
			}
		}
	}
	
	func viewDidAppear() {
		initialize()
	}
	
	func viewDidDisappear() {
		deepReload(nil)
		itemViewWithMouseOver = nil
		NSWorkspace.shared.notificationCenter.removeObserver(self)
	}
	
	@objc private func deepReload(_ notification: NSNotification?) {
		self.dockItems.removeAll()
		self.persistentItems.removeAll()
		self.cachedDockItemViews.removeAll()
		self.cachedPersistentItemViews.removeAll()
		self.dockScrubber.reloadData()
		self.persistentScrubber.reloadData()
		if notification == nil {
			return
		}
		self.dockRepository = DockRepository(delegate: self)
		print("[DockWidget]: DEEP RELOAD")
	}
	
	/// Configure stack view
	private func configureStackView() {
		stackView.alignment = .centerY
		stackView.orientation = .horizontal
		stackView.distribution = .fill
	}
	
	@objc private func displayScrubbers() {
		self.separator.isHidden          = Preferences[.hidePersistentItems] || persistentItems.isEmpty
		self.persistentScrubber.isHidden = Preferences[.hidePersistentItems] || persistentItems.isEmpty
	}
	
	@objc private func reloadScrubbersLayout() {
		cachedDockItemViews.removeAll()
		let dockLayout              = NSScrubberFlowLayout()
		dockLayout.itemSize         = Constants.dockItemSize
		dockLayout.itemSpacing      = Preferences[.itemSpacing]
		dockScrubber.scrubberLayout = dockLayout
		dockScrubber.reloadData()
		cachedPersistentItemViews.removeAll()
		let persistentLayout              = NSScrubberFlowLayout()
		persistentLayout.itemSize         = Constants.dockItemSize
		persistentLayout.itemSpacing      = Preferences[.itemSpacing]
		persistentScrubber.scrubberLayout = persistentLayout
		persistentScrubber.reloadData()
	}
	
	/// Configure dock scrubber
	private func configureDockScrubber() {
		let layout = NSScrubberFlowLayout()
		layout.itemSize    = Constants.dockItemSize
		layout.itemSpacing = Preferences[.itemSpacing]
		dockScrubber.dataSource = self
		dockScrubber.delegate = self
		dockScrubber.showsAdditionalContentIndicators = true
		dockScrubber.mode = .free
		dockScrubber.isContinuous = false
		dockScrubber.itemAlignment = .none
		dockScrubber.scrubberLayout = layout
		stackView.addArrangedSubview(dockScrubber)
	}
	
	/// Configure separator
	private func configureSeparator() {
		separator.wantsLayer = true
		separator.layer?.backgroundColor = NSColor.darkGray.cgColor
		separator.width(1)
		separator.height(20)
		stackView.addArrangedSubview(separator)
	}
	
	/// Configure persistent scrubber
	private func configurePersistentScrubber() {
		let layout = NSScrubberFlowLayout()
		layout.itemSize    = Constants.dockItemSize
		layout.itemSpacing = Preferences[.itemSpacing]
		persistentScrubber.dataSource = self
		persistentScrubber.delegate = self
		persistentScrubber.showsAdditionalContentIndicators = true
		persistentScrubber.mode = .free
		persistentScrubber.isContinuous = false
		persistentScrubber.itemAlignment = .none
		persistentScrubber.scrubberLayout = layout
		persistentScrubberWidthConstraint.constant = (Constants.dockItemSize.width + 8) * CGFloat(min(persistentItems.count, 3))
		stackView.addArrangedSubview(persistentScrubber)
	}
	
	// MARK: ScreenEdgeMouseDelegate (Select, Scroll & Drag)
	func screenEdgeController(_ controller: PKScreenEdgeController, mouseEnteredAtLocation location: NSPoint, in view: NSView) {
		updateCursorLocation(location, in: view)
	}
	
	func screenEdgeController(_ controller: PKScreenEdgeController, mouseExitedAtLocation location: NSPoint, in view: NSView) {
		itemViewWithMouseOver?.set(isMouseOver: false)
	}
	
	func screenEdgeController(_ controller: PKScreenEdgeController, mouseMovedAtLocation location: NSPoint, in view: NSView) {
		updateCursorLocation(location, in: view)
	}
	
	func screenEdgeController(_ controller: PKScreenEdgeController, mouseScrollWithDelta delta: CGFloat, atLocation location: NSPoint, in view: NSView) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		guard let scrubber = scrubber(at: location, in: view) else {
			return
		}
		scrubber.scroll(with: delta)
	}
	
	func screenEdgeController(_ controller: PKScreenEdgeController, mouseClickAtLocation location: NSPoint, in view: NSView) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		launchItem(item(at: location, in: view))
	}
	
	 func screenEdgeController(_ controller: PKScreenEdgeController, draggingEntered info: NSDraggingInfo, filepath: String, in view: NSView) -> NSDragOperation {
		itemViewWithMouseOver?.set(isMouseOver: false)
		return .every
	}
	
	func screenEdgeController(_ controller: PKScreenEdgeController, draggingUpdated info: NSDraggingInfo, filepath: String, in view: NSView) -> NSDragOperation {
		let location = info.draggingLocation
		let item = self.item(at: location, in: view)
		if let item = item, item.isRunning, let itemView = itemView(at: location, in: view) {
			if dropDispatchWorkItem == nil {
				dropDispatchWorkItem = DispatchWorkItem { [weak self, item, itemView] in
					if self?.itemViewWithDraggingOver == itemView {
						NSLog("[DockWidget]: Ready to launch: `\(item.bundleIdentifier ?? "unknown")`")
						self?.launchItem(item)
					}
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: dropDispatchWorkItem!)
			}
			itemViewWithDraggingOver = itemView
		}else {
			if itemViewWithDraggingOver != nil {
				itemViewWithDraggingOver = nil
				dropDispatchWorkItem?.cancel()
				dropDispatchWorkItem  = nil
			}
		}
		updateCursorLocation(location, in: view)
		return .every
	}
	
	func screenEdgeController(_ controller: PKScreenEdgeController, performDragOperation info: NSDraggingInfo, filepath: String, in view: NSView) -> Bool {
		guard let item = item(at: info.draggingLocation, in: view) else {
			return false
		}
		let filePathURL = URL(fileURLWithPath: filepath)
		if let bundleIdentifier = item.bundleIdentifier {
			return NSWorkspace.shared.open([filePathURL], withAppBundleIdentifier: bundleIdentifier, options: .withErrorPresentation, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
		}else if let destinationPathURL = item.path?.appendingPathComponent(filePathURL.lastPathComponent) {
			do {
				if item.path?.relativePath == Constants.trashPath {
					try FileManager.default.trashItem(at: filePathURL, resultingItemURL: nil)
					persistentScrubber?.reloadData()
					SystemSound.play(.move_to_trash)
				}else {
					try FileManager.default.moveItem(at: filePathURL, to: destinationPathURL)
					SystemSound.play(.volume_mount)
				}
				return true
			}catch {
				print("[DockWidget][mv] Error: \(error.localizedDescription)")
				NSSound.beep()
				return false
			}
		}
		return false
	}
	
	private func updateCursorLocation(_ location: NSPoint?, in view: NSView) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = nil
		guard let location = location else {
			return
		}
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = itemView(at: location, in: view)
		itemViewWithMouseOver?.set(isMouseOver: true)
	}
	
}

extension DockWidget: DockDelegate {

	func didUpdateDockItem(_ item: DockItem, at index: Int, terminated: Bool, isDefaults: Bool) {
		DispatchQueue.main.async { [weak self, item] in
			guard let self = self else {
				return
			}
			if let itemView = self.itemView(for: item) {
				if let currentIndex = self.dockItems.firstIndex(where: { $0.bundleIdentifier == item.bundleIdentifier }) {
					if terminated && !isDefaults {
						self.dockItems.remove(at: currentIndex)
						self.dockScrubber.removeItems(at: IndexSet(integer: currentIndex))
						if let cachedViewIndex = self.cachedDockItemViews.firstIndex(where: { $0.diffId == item.diffId }) {
							self.cachedDockItemViews.remove(at: cachedViewIndex)
						}
					}else {
						itemView.set(isRunning:   item.isRunning)
						itemView.set(isFrontmost: item.isFrontmost)
						itemView.set(isLaunching: item.isLaunching)
						self.dockScrubber.reloadItems(at: IndexSet(integer: currentIndex))
					}
				}
			}else {
				if self.dockItems.contains(item) == false {
					if index < self.dockItems.count {
						self.dockItems.remove(at: index)
						self.dockItems.insert(item, at: index)
						self.dockScrubber.reloadItems(at: IndexSet(integer: index))
					}else {
						let validIndex = self.dockItems.count
						self.dockItems.append(item)
						self.dockScrubber.insertItems(at: IndexSet(integer: validIndex))
						self.dockScrubber.animator().scrollItem(at: validIndex, to: .center)
					}
				}else {
					self.dockScrubber.reloadData()
				}
			}
			/// Do another check because of a bug in `NSScrubber`
			if self.dockScrubber.numberOfItems != self.dockItems.count {
				self.dockScrubber.reloadData()
			}else {
				if terminated && !isDefaults {
					for (index,item) in self.dockItems.enumerated() {
						self.updateView(for: item, isPersistent: item.isPersistentItem)
						self.dockScrubber.reloadItems(at: IndexSet(integer: index))
					}
				}
			}
		}
	}
	
	func didUpdateActiveItem(_ item: DockItem, at index: Int, activated: Bool) {
		DispatchQueue.main.async { [weak self] in
			guard let index = self?.dockItems.firstIndex(of: item), let view = self?.cachedDockItemViews.first(where: { $0.diffId == item.diffId }) else {
				return
			}
			view.set(isFrontmost: activated)
			if activated {
				self?.dockScrubber.animator().scrollItem(at: index, to: .center)
			}
		}
	}
	
	func didUpdateBadge(for apps: [DockItem]) {
		DispatchQueue.main.async { [weak self] in
			guard let s = self else { return }
			s.cachedDockItemViews.forEach({ view in
				view.set(hasBadge: apps.first(where: { $0.diffId == view.diffId })?.hasBadge ?? false)
			})
		}
	}
	
	func didUpdatePersistentItem(_ item: DockItem, at index: Int, added: Bool) {
		DispatchQueue.main.async { [weak self, item] in
			guard let self = self else {
				return
			}
			if let itemIndex = self.persistentItems.firstIndex(where: { $0.path == item.path }), let itemView = self.itemView(for: item) {
				if added {
					itemView.set(icon: item.icon)
					self.persistentScrubber.reloadItems(at: IndexSet(integer: itemIndex))
				}else {
					self.persistentScrubber.removeItems(at: IndexSet(integer: itemIndex))
					self.persistentItems.remove(at: itemIndex)
					if let index = self.cachedPersistentItemViews.firstIndex(where: { $0.diffId == item.diffId }) {
						self.cachedPersistentItemViews.remove(at: index)
					}
				}
			}else {
				self.persistentItems.insert(item, at: index)
				self.persistentScrubber.insertItems(at: IndexSet(integer: index))
			}
			self.displayScrubbers()
			self.persistentScrubberWidthConstraint.constant = (Constants.dockItemSize.width + 8) * CGFloat(min(self.persistentItems.count, 3))
		}
	}
	
	@discardableResult
	private func updateView(for item: DockItem?, isPersistent: Bool) -> DockItemView? {
		guard let item = item else {
			return nil
		}
		var view: DockItemView! = {
			return cachedDockItemViews.first(where: { $0.diffId == item.diffId }) ?? cachedPersistentItemViews.first(where: { $0.diffId == item.diffId })
		}()
		if view == nil {
			view = DockItemView(frame: .zero)
			if isPersistent {
				cachedPersistentItemViews.append(view)
			}else {
				cachedDockItemViews.append(view)
			}
		}
		view.diffId = item.diffId
		view.clear()
		view.set(icon:        item.icon)
		view.set(hasBadge:    item.hasBadge)
		view.set(isRunning:   item.isRunning)
		view.set(isFrontmost: item.isFrontmost)
		return view
	}

}

extension DockWidget: NSScrubberDataSource {
	func numberOfItems(for scrubber: NSScrubber) -> Int {
		if scrubber == persistentScrubber {
			return persistentItems.count
		}
		return dockItems.count
	}
	
	func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
		let isPersistent = scrubber == persistentScrubber
		let item = isPersistent ? persistentItems[index] : dockItems[index]
		return updateView(for: item, isPersistent: isPersistent)!
	}
}

extension DockWidget: NSScrubberDelegate {
	
	func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
		let item = scrubber == persistentScrubber ? persistentItems[selectedIndex] : dockItems[selectedIndex]
		launchItem(item)
		scrubber.selectedIndex = -1
	}
	
	func didBeginInteracting(with scrubber: NSScrubber) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = nil
	}
	
	func launchItem(_ item: DockItem?) {
		guard let item = item else {
			return
		}
		if !item.isPersistentItem, !item.isRunning, item.bundleIdentifier != Constants.kLaunchpadIdentifier, let itemView = itemView(for: item) {
			itemView.set(isLaunching: true)
		}
		dockRepository.launch(item: item, completion: { _ in })
	}
}

// MARK: Retrieve DockItem & DockItemView
extension DockWidget {
	private func scrubber(at location: NSPoint?, in view: NSView) -> NSScrubber? {
		guard let location = location else {
			return nil
		}
		if dockScrubber.convert(dockScrubber.bounds, to: view).contains(location) {
			return dockScrubber
		}
		if persistentScrubber.convert(persistentScrubber.bounds, to: view).contains(location) {
			return persistentScrubber
		}
		return nil
	}
	
	private func item(at location: NSPoint, in view: NSView) -> DockItem? {
		guard let itemView = itemView(at: location, in: view) else {
			return nil
		}
		return dockItems.first(where: { $0.diffId == itemView.diffId }) ?? persistentItems.first(where: { $0.diffId == itemView.diffId })
	}
	
	private func itemView(at location: NSPoint?, in view: NSView) -> DockItemView? {
		guard let scrubber = scrubber(at: location, in: view), let itemView = scrubber.subview(in: view, at: location, of: DockItemView.self) else {
			return nil
		}
		if let location = location {
			let loc = NSPoint(x: location.x + 6, y: 12)
			if itemView.convert(itemView.iconView.frame, to: view).contains(loc) {
				return itemView
			}
		}
		return nil
	}
	
	private func itemView(for item: DockItem) -> DockItemView? {
		guard let result = cachedPersistentItemViews.first(where: { $0.diffId == item.diffId }) else {
			return cachedDockItemViews.first(where: { $0.diffId == item.diffId })
		}
		return result
	}
}
