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

class DockWidget: NSObject, PKWidget {
    
    var identifier: NSTouchBarItem.Identifier = NSTouchBarItem.Identifier(rawValue: "DockWidget")
    var customizationLabel: String = "Dock"
    var view: NSView!
    
    /// Core
    private var dockRepository:       DockRepository!
	private var screenEdgeController: ScreenEdgeController?
	
	private var dockContentSize: CGFloat {
		return dockScrubber.visibleRect.width
	}
	private var persistentContentSize: CGFloat {
		return persistentScrubber.visibleRect.width
	}
	private var totalContentSizeWidth: CGFloat {
		let max = NSScreen.main?.frame.width ?? CGFloat.greatestFiniteMagnitude
		return min(dockContentSize + persistentContentSize + (stackView.spacing * 2) + 8, max)
	}
    
    /// UI
    private var stackView:          NSStackView! = NSStackView(frame: .zero)
    private var dockScrubber:       NSScrubber!  = NSScrubber(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
    private var separator:          NSView! 	 = NSView(frame:     NSRect(x: 0, y: 0, width: 1, 	height: 20))
    private var persistentScrubber: NSScrubber!  = NSScrubber(frame: NSRect(x: 0, y: 0, width: 50, 	height: 30))
	
	/// Mouse + drang-and-drop
	private var cursorView:		  NSView?
	private var draggingInfoView: DraggingInfoView?
	private var dropDispatchWorkItem: DispatchWorkItem?
    
    /// Data
    private var dockItems:       [DockItem] = []
    private var persistentItems: [DockItem] = []
    private var cachedDockItemViews: 	   [Int: DockItemView] = [:]
	private var cachedPersistentItemViews: [Int: DockItemView] = [:]
	private var itemViewWithMouseOver: 	  DockItemView?
	private var itemViewWithDraggingOver: DockItemView?
    
    required override init() {
        super.init()
        self.configureStackView()
        self.configureDockScrubber()
        self.configureSeparator()
        self.configurePersistentScrubber()
        self.displayScrubbers()
        self.view = stackView
        self.dockRepository = DockRepository(delegate: self)
        self.dockRepository.reload(nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displayScrubbers), 			 name: .shouldReloadPersistentItems, 	  object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reloadScrubbersLayout), 	 name: .shouldReloadScrubbersLayout, 	  object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reloadScreenEdgeController), name: .shouldReloadScreenEdgeController, object: nil)
		self.reloadScreenEdgeController()
    }
    
    deinit {
        stackView           = nil
        dockScrubber        = nil
        separator           = nil
        persistentScrubber  = nil
		cursorView			= nil
        dockRepository      = nil
		itemViewWithMouseOver = nil
		screenEdgeController = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
	
	func viewWillDisappear() {
		screenEdgeController?.tearDown()
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
	
	@objc private func reloadScreenEdgeController() {
		if Defaults[.hasMouseSupport] {
			self.screenEdgeController = ScreenEdgeController(mouseDelegate: self)
			self.screenEdgeController?.contentSize = self.totalContentSizeWidth
		}else {
			self.screenEdgeController = nil
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
    
}

extension DockWidget: DockDelegate {
    func didUpdate(apps: [DockItem]) {
        update(scrubber: dockScrubber, oldItems: dockItems, newItems: apps) { [weak self] apps in
            apps.enumerated().forEach({ index, item in
                item.index = index
            })
            self?.dockItems = apps
        }
    }
    func didUpdate(items: [DockItem]) {
        update(scrubber: persistentScrubber, oldItems: persistentItems, newItems: items) { [weak self] items in
            self?.persistentItems = items
            self?.displayScrubbers()
            self?.persistentScrubber.snp.updateConstraints({ m in
                m.width.equalTo((Constants.dockItemSize.width + 8) * CGFloat(self?.persistentItems.count ?? 0))
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
    
    private func update(scrubber: NSScrubber?, oldItems: [DockItem], newItems: [DockItem], completion: (([DockItem]) -> Void)? = nil) {
        guard let scrubber = scrubber else {
            completion?(newItems)
            return
        }
        DispatchQueue.main.async { [weak self] in
			guard let self = self else {
				return
			}
			completion?(newItems)
            scrubber.reloadData()
			self.screenEdgeController?.contentSize = self.totalContentSizeWidth
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
	func didUpdateRunningState(for apps: [DockItem], shouldScroll: Bool) {
        DispatchQueue.main.async { [weak self, apps, shouldScroll] in
            guard let self = self else { return }
			for item in apps {
				if let itemView = self.itemView(for: item) {
					itemView.set(isRunning:   item.isRunning)
					itemView.set(isFrontmost: item.isFrontmost)
					itemView.set(isLaunching: item.isLaunching)
					if shouldScroll, item.isPersistentItem == false, item.isFrontmost == true {
						let adjust = self.dockItems.count > (item.index + 1) ? 1 : 0
						self.dockScrubber?.animator().scrollItem(at: item.index + adjust, to: .center)
					}
				}
			}
        }
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

// MARK: Cursor stuff
extension DockWidget {
	private func showCursor(_ cursor: NSCursor?, at location: NSPoint?) {
		cursorView?.removeFromSuperview()
		cursorView = nil
		guard let cursor = cursor, let location = location else {
			updateCursorLocation(nil)
			return
		}
		if Defaults[.showCursor] {
			cursorView = NSImageView(image: cursor.image)
			cursorView?.frame.size = NSSize(width: 20, height: 20)
			view.addSubview(cursorView!)
		}
		updateCursorLocation(location)
	}
	
	private func updateCursorLocation(_ location: NSPoint?) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = nil
		guard let location = location else {
			return
		}
		cursorView?.frame.origin = location
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = itemView(at: location)
		itemViewWithMouseOver?.set(isMouseOver: true)
	}
	
	private func showDraggingInfo(_ info: NSDraggingInfo?, filepath: String?) {
		draggingInfoView?.removeFromSuperview()
		draggingInfoView = nil
		guard let info = info, let filepath = filepath else {
			return
		}
		if Defaults[.showCursor] {
			draggingInfoView = DraggingInfoView(filepath: URL(fileURLWithPath: filepath))
			view.addSubview(draggingInfoView!, positioned: .below, relativeTo: cursorView)
		}
		updateDraggingInfoLocation(info.draggingLocation, animated: false)
	}
	
	private func updateDraggingInfoLocation(_ location: NSPoint, animated: Bool = true) {
		guard let view = draggingInfoView else {
			return
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.1275 : 0), execute: {
			view.frame.origin = NSPoint(x: location.x - view.frame.width + 8, y: location.y)
		})
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

// MARK: ScreenEdgeMouseDelegate (Select, Scroll & Drag)
extension DockWidget: ScreenEdgeMouseDelegate {
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseEnteredAtLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		showCursor(.arrow, at: location)
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseMovedAtLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		updateCursorLocation(location)
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseScrollWithDelta delta: CGFloat, atLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		guard let scrubber = (dockContentSize - location.x) > 0 ? dockScrubber : persistentScrubber,
			  let clipView: NSClipView = scrubber.findViews().first,
			  let scrollView: NSScrollView = scrubber.findViews().first else {
			return
		}
		let maxWidth = scrubber.contentSize.width - scrubber.visibleRect.width
		let newX     = clipView.bounds.origin.x - delta
		if maxWidth > 0, (-6...maxWidth+6).contains(newX) {
			clipView.setBoundsOrigin(NSPoint(x: newX, y: clipView.bounds.origin.y))
			scrollView.reflectScrolledClipView(clipView)
		}
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseClickAtLocation location: NSPoint) {
		launchItem(item(at: location))
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, draggingEntered info: NSDraggingInfo, filepath: String) -> NSDragOperation {
		itemViewWithMouseOver?.set(isMouseOver: false)
		showDraggingInfo(info, filepath: filepath)
		return .every
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, draggingUpdated info: NSDraggingInfo, filepath: String) -> NSDragOperation {
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
	
	func screenEdgeController(_ controller: ScreenEdgeController, performDragOperation info: NSDraggingInfo, filepath: String) -> Bool {
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
	
	func screenEdgeController(_ controller: ScreenEdgeController, draggingEnded info: NSDraggingInfo) {
		showCursor(.arrow, at: info.draggingLocation)
		showDraggingInfo(nil, filepath: nil)
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseExitedAtLocation location: NSPoint) {
		showCursor(nil, at: nil)
		showDraggingInfo(nil, filepath: nil)
	}
	
}
