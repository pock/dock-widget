//
//  DockWidget.swift
//  Pock
//
//  Created by Pierluigi Galdi on 06/04/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Defaults
import PockKit

class DockWidget: PKScreenEdgeBaseController, PKWidget {
	
	var identifier: NSTouchBarItem.Identifier = NSTouchBarItem.Identifier(rawValue: "DockWidget")
	var customizationLabel: String = "Dock"
	var view: NSView!
	
	/// Core
	private var dockRepository: DockRepository!
	
	private var dockContentSize: CGFloat {
		return dockScrubber.visibleRect.width
	}
	private var persistentContentSize: CGFloat {
		return persistentScrubber.visibleRect.width
	}
	override var visibleRectWidth: CGFloat {
		get {
			let max = NSScreen.main?.frame.width ?? CGFloat.greatestFiniteMagnitude
			return min(dockContentSize + persistentContentSize + stackView.spacing + Constants.dockItemSize.width, max)
		}
		set { /**/ }
	}
	
	override var parentView: NSView? {
		get {
			return view
		}
		set { /**/ }
	}
	private var dropDispatchWorkItem: DispatchWorkItem?
	
	/// UI
	private var stackView:          NSStackView! = NSStackView(frame: .zero)
	private var dockScrubber:       NSScrubber!  = NSScrubber(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
	private var separator:          NSView! 	 = NSView(frame:     NSRect(x: 0, y: 0, width: 1, 	height: 20))
	private var persistentScrubber: NSScrubber!  = NSScrubber(frame: NSRect(x: 0, y: 0, width: 50, 	height: 30))
	
	/// Data
	private var dockItems:       [DockItem] = []
	private var persistentItems: [DockItem] = []
	private var cachedDockItemViews: 	   [Int: DockItemView] = [:]
	private var cachedPersistentItemViews: [Int: DockItemView] = [:]
	private var itemViewWithMouseOver: 	  DockItemView?
	private var itemViewWithDraggingOver: DockItemView?
	
	required init() {
		super.init()
		self.configureStackView()
		self.configureDockScrubber()
		self.configureSeparator()
		self.configurePersistentScrubber()
		self.displayScrubbers()
		self.view = stackView
		self.dockRepository = DockRepository(delegate: self)
		// TODO: self.dockRepository.reload(nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displayScrubbers), 	    name: .shouldReloadPersistentItems, object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reloadScrubbersLayout), name: .shouldReloadScrubbersLayout, object: nil)
	}
	
	deinit {
		stackView           = nil
		dockScrubber        = nil
		separator           = nil
		persistentScrubber  = nil
		cursorView			= nil
		dockRepository      = nil
		itemViewWithMouseOver = nil
		NSWorkspace.shared.notificationCenter.removeObserver(self)
	}
	
	func viewWillDisappear() {
		edgeController?.tearDown()
	}
	
	/// Configure stack view
	private func configureStackView() {
		stackView.alignment = .centerY
		stackView.orientation = .horizontal
		stackView.distribution = .fill
	}
	
	@objc private func displayScrubbers() {
		self.separator.isHidden          = Defaults[.hidePersistentItems] || persistentItems.isEmpty
		self.persistentScrubber.isHidden = Defaults[.hidePersistentItems] || persistentItems.isEmpty
	}
	
	override func reloadScreenEdgeController() {
		if Defaults[.hasMouseSupport] {
			super.reloadScreenEdgeController()
		}else {
			edgeController?.tearDown()
		}
	}
	
	@objc private func reloadScrubbersLayout() {
		let dockLayout              = NSScrubberFlowLayout()
		dockLayout.itemSize         = Constants.dockItemSize
		dockLayout.itemSpacing      = CGFloat(Defaults[.itemSpacing])
		dockScrubber.scrubberLayout = dockLayout
		let persistentLayout              = NSScrubberFlowLayout()
		persistentLayout.itemSize         = Constants.dockItemSize
		persistentLayout.itemSpacing      = CGFloat(Defaults[.itemSpacing])
		persistentScrubber.scrubberLayout = persistentLayout
	}
	
	/// Configure dock scrubber
	private func configureDockScrubber() {
		let layout = NSScrubberFlowLayout()
		layout.itemSize    = Constants.dockItemSize
		layout.itemSpacing = CGFloat(Defaults[.itemSpacing])
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
		separator.snp.makeConstraints({ m in
			m.width.equalTo(1)
			m.height.equalTo(20)
		})
		stackView.addArrangedSubview(separator)
	}
	
	/// Configure persistent scrubber
	private func configurePersistentScrubber() {
		let layout = NSScrubberFlowLayout()
		layout.itemSize    = Constants.dockItemSize
		layout.itemSpacing = CGFloat(Defaults[.itemSpacing])
		persistentScrubber.dataSource = self
		persistentScrubber.delegate = self
		persistentScrubber.showsAdditionalContentIndicators = true
		persistentScrubber.mode = .free
		persistentScrubber.isContinuous = false
		persistentScrubber.itemAlignment = .none
		persistentScrubber.scrubberLayout = layout
		persistentScrubber.snp.makeConstraints({ m in
			m.width.equalTo((Constants.dockItemSize.width + 8) * CGFloat(persistentItems.count))
		})
		stackView.addArrangedSubview(persistentScrubber)
	}
	
	// MARK: ScreenEdgeMouseDelegate (Select, Scroll & Drag)
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseEnteredAtLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		showCursor(.arrow, at: location)
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseMovedAtLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		updateCursorLocation(location)
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseScrollWithDelta delta: CGFloat, atLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		guard let scrubber = (dockContentSize - location.x) > 0 ? dockScrubber : persistentScrubber else {
			return
		}
		scrubber.scroll(with: delta)
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseClickAtLocation location: NSPoint) {
		launchItem(item(at: location))
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, draggingEntered info: NSDraggingInfo, filepath: String) -> NSDragOperation {
		itemViewWithMouseOver?.set(isMouseOver: false)
		showDraggingInfo(info, filepath: filepath)
		return .every
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, draggingUpdated info: NSDraggingInfo, filepath: String) -> NSDragOperation {
		let location = info.draggingLocation
		let item = self.item(at: location)
		updateDraggingInfoLocation(location)
		if let item = item, item.isRunning, let itemView = itemView(at: location) {
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
		showCursor(item?.isPersistentItem == true ? .dragCopy : .arrow, at: location)
		updateCursorLocation(location)
		return .every
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, performDragOperation info: NSDraggingInfo, filepath: String) -> Bool {
		showDraggingInfo(nil, filepath: nil)
		guard let item = item(at: info.draggingLocation) else {
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
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, draggingEnded info: NSDraggingInfo) {
		showCursor(.arrow, at: info.draggingLocation)
		showDraggingInfo(nil, filepath: nil)
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseExitedAtLocation location: NSPoint) {
		showCursor(nil, at: nil)
		showDraggingInfo(nil, filepath: nil)
	}
	
	// MARK: Cursor Stuff
	override func showCursor(_ cursor: NSCursor?, at location: NSPoint?) {
		guard Defaults[.showCursor] else {
			return
		}
		super.showCursor(cursor, at: location)
	}
	
	override func updateCursorLocation(_ location: NSPoint?) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = nil
		guard let location = location else {
			return
		}
		super.updateCursorLocation(location)
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = itemView(at: location)
		itemViewWithMouseOver?.set(isMouseOver: true)
	}
	
	override func showDraggingInfo(_ info: NSDraggingInfo?, filepath: String?) {
		guard Defaults[.showCursor] else {
			return
		}
		super.showDraggingInfo(info, filepath: filepath)
	}
	
}

extension DockWidget: DockDelegate {

	func didUpdateDockItem(_ item: DockItem, at index: Int, terminated: Bool, isDefaults: Bool) {
		DispatchQueue.main.async { [weak self, item] in
			guard let self = self else {
				return
			}
			defer {
				self.reloadScreenEdgeController()
			}
			if let itemView = self.itemView(for: item) {
				if let currentIndex = self.dockItems.firstIndex(where: { $0.bundleIdentifier == item.bundleIdentifier }) {
					if terminated && !isDefaults {
						self.dockItems.remove(at: currentIndex)
						self.dockScrubber.removeItems(at: IndexSet(integer: currentIndex))
						if let cachedViewIndex = self.cachedDockItemViews.firstIndex(where: { $0.key == item.diffId }) {
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
			guard let view = self?.cachedDockItemViews.first(where: { $0.key == item.diffId })?.value else {
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
			s.cachedDockItemViews.forEach({ key, view in
				view.set(hasBadge: apps.first(where: { $0.diffId == key })?.hasBadge ?? false)
			})
		}
	}
	
	func didUpdatePersistentItem(_ item: DockItem, at index: Int, added: Bool) {
		DispatchQueue.main.async { [weak self, item] in
			guard let self = self else {
				return
			}
			if let itemIndex = self.persistentItems.firstIndex(where: { $0.bundleIdentifier == item.bundleIdentifier }), let itemView = self.itemView(for: item) {
				if added {
					itemView.set(icon: item.icon)
					self.persistentScrubber.reloadItems(at: IndexSet(integer: itemIndex))
				}else {
					self.persistentScrubber.removeItems(at: IndexSet(integer: itemIndex))
					if let index = self.cachedPersistentItemViews.firstIndex(where: { $0.key == item.diffId }) {
						self.cachedPersistentItemViews.remove(at: index)
					}
				}
			}else {
				self.persistentItems.insert(item, at: index)
				self.persistentScrubber.insertItems(at: IndexSet(integer: index))
			}
			self.displayScrubbers()
			self.persistentScrubber.snp.updateConstraints({ m in
				m.width.equalTo((Constants.dockItemSize.width + 8) * CGFloat(self.persistentItems.count))
			})
		}
	}
	
	@discardableResult
	private func updateView(for item: DockItem?, isPersistent: Bool) -> DockItemView? {
		guard let item = item else { return nil }
		var view: DockItemView! = isPersistent ? cachedPersistentItemViews[item.diffId] : cachedDockItemViews[item.diffId]
		if view == nil {
			view = DockItemView(frame: .zero)
			if isPersistent {
				cachedPersistentItemViews[item.diffId] = view
			}else {
				cachedDockItemViews[item.diffId] = view
			}
		}
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
	
	func didFinishInteracting(with scrubber: NSScrubber) {
		showCursor(.arrow, at: cursorView?.frame.origin)
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
	private func item(at location: NSPoint) -> DockItem? {
		let loc = NSPoint(x: location.x + 6, y: 12)
		guard let result = cachedPersistentItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
			guard let result = cachedDockItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
				return nil
			}
			return dockItems.first(where: { $0.diffId == result.key })
		}
		return persistentItems.first(where: { $0.diffId == result.key })
	}
	
	private func itemView(at location: NSPoint) -> DockItemView? {
		let loc = NSPoint(x: location.x + 6, y: 12)
		guard let result = cachedPersistentItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
			guard let result = cachedDockItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
				return nil
			}
			return result.value
		}
		return result.value
	}
	
	private func itemView(for item: DockItem) -> DockItemView? {
		guard let result = cachedPersistentItemViews.first(where: { $0.key == item.diffId })?.value else {
			return cachedDockItemViews.first(where: { $0.key == item.diffId })?.value
		}
		return result
	}
}
