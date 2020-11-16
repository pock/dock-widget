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
	
	private var dockMaxWidth: CGFloat {
		if Defaults[.showCursor] {
			return dockScrubber.visibleRect.width
		}
		return (Constants.dockItemSize.width + CGFloat(Defaults[.itemSpacing])) * CGFloat(dockItems.count)
	}
	private var persistentMaxWidth: CGFloat {
		if Defaults[.showCursor] {
			return persistentScrubber.visibleRect.width
		}
		return (Constants.dockItemSize.width + CGFloat(Defaults[.itemSpacing])) * CGFloat(persistentItems.count)
	}
	private var totalMaxWidth: CGFloat {
		return min(dockMaxWidth + persistentMaxWidth, NSScreen.main?.frame.width ?? CGFloat.greatestFiniteMagnitude)
	}
    
    /// UI
    private var stackView:          NSStackView! = NSStackView(frame: .zero)
    private var dockScrubber:       NSScrubber! = NSScrubber(frame: NSRect(x: 0, y: 0, width: 200,  height: 30))
    private var separator:          NSView! = NSView(frame:     NSRect(x: 0, y: 0, width: 1,    height: 20))
    private var persistentScrubber: NSScrubber! = NSScrubber(frame: NSRect(x: 0, y: 0, width: 50,   height: 30))
	private var cursorView:			NSView?
    
    /// Data
    private var dockItems:       [DockItem] = []
    private var persistentItems: [DockItem] = []
    private var cachedDockItemViews: 	   [Int: DockItemView] = [:]
	private var cachedPersistentItemViews: [Int: DockItemView] = [:]
	private var itemViewWithMouseOver: DockItemView?
    
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
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reloadDockScrubberLayout), 	 name: .shouldReloadDockLayout, 		  object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reloadScreenEdgeController), name: .shouldReloadScreenEdgeController, object: nil)
		self.reloadScreenEdgeController()
    }
    
    deinit {
        stackView           = nil
        dockScrubber        = nil
        separator           = nil
        persistentScrubber  = nil
        dockRepository      = nil
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
		if Defaults[.hasMouseSupport] && self.screenEdgeController == nil {
			self.screenEdgeController = ScreenEdgeController(delegate: self)
			self.screenEdgeController?.contentSize = self.totalMaxWidth
		}else {
			self.screenEdgeController = nil
		}
	}
    
    @objc private func reloadDockScrubberLayout() {
		cachedDockItemViews.removeAll()
		cachedPersistentItemViews.removeAll()
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
			self.screenEdgeController?.contentSize = self.totalMaxWidth
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
    func didUpdateRunningState(for apps: [DockItem]) {
        DispatchQueue.main.async { [weak self] in
            guard let s = self else { return }
            s.cachedDockItemViews.forEach({ key, view in
                let item = apps.first(where: { $0.diffId == key })
                view.set(isRunning:   item?.isRunning   ?? false)
                view.set(isFrontmost: item?.isFrontmost ?? false)
                view.set(isLaunching: item?.isLaunching ?? false)
				if let i = item, i.isFrontmost && !i.isPersistentItem {
					let adjust = apps.count > (i.index + 1) ? 1 : 0
					s.dockScrubber?.animator().scrollItem(at: i.index + adjust, to: .center)
				}
            })
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
		showCursor(at: cursorView?.frame.origin)
	}
	
	func launchItem(_ item: DockItem?) {
		guard let item = item else {
			return
		}
		var result: Bool = false
		if item.bundleIdentifier?.lowercased() == "com.apple.finder" {
			dockRepository.launch(bundleIdentifier: item.bundleIdentifier, completion: { result = $0 })
		}else {
			dockRepository.launch(item: item, completion: { result = $0 })
		}
		print("[DockWidget]: Did open: \(item.bundleIdentifier ?? item.path?.absoluteString ?? "Unknown") [success: \(result)]")
	}
}

extension DockWidget: ScreenEdgeDelegate {
	
	private func itemView(in superview: NSView, at location: NSPoint) -> DockItemView? {
		let loc = NSPoint(x: location.x + CGFloat(Defaults[.itemSpacing]), y: 12)
		guard let itemView = cachedDockItemViews.values.first(where: { $0.convert($0.iconView.frame, to: self.view).contains(loc) }) else {
			return cachedPersistentItemViews.values.first(where: { $0.convert($0.iconView.frame, to: self.view).contains(loc) })
		}
		return itemView
	}
	
	private func showCursor(at location: NSPoint?) {
		guard Defaults[.showCursor], let location = location else {
			cursorView?.removeFromSuperview()
			cursorView = nil
			return
		}
		if cursorView == nil {
			cursorView = NSImageView(image: NSCursor.pointingHand.image)
			view.addSubview(cursorView!)
		}
		cursorView?.frame = NSRect(x: location.x, y: location.y, width: 26, height: 26)
		itemViewWithMouseOver = itemView(in: view, at: location)
		itemViewWithMouseOver?.set(isMouseOver: true)
	}
	
	private func item(at location: NSPoint?, in scrubber: NSScrubber?) -> DockItem? {
		guard let location = location, let scrubber = scrubber else {
			return nil
		}
		let items 	 = scrubber == dockScrubber ? dockItems : persistentItems
		let maxWidth = scrubber == dockScrubber ? dockMaxWidth : persistentMaxWidth
		let position = scrubber == dockScrubber ? location.x : (location.x - dockMaxWidth)
		let percentage = position / maxWidth
		let index  = Int(CGFloat(items.count) * percentage)
		let adjust = items.count > (index + 1) ? 1 : 0
		scrubber.animator().scrollItem(at: index + adjust, to: .center)
		return items[index]
	}
	
	private func itemView(at location: NSPoint?, in scrubber: NSScrubber?) -> DockItemView? {
		guard let item = item(at: location, in: scrubber) else {
			return nil
		}
		let views = scrubber == dockScrubber ? cachedDockItemViews : cachedPersistentItemViews
		return views.first(where: { $0.key == item.diffId })?.value
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseMovedAtLocation location: NSPoint?) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		guard Defaults[.showCursor] else {
			let adjustedLocation  = dockMaxWidth - (location?.x ?? 0)
			let scrubber		  = adjustedLocation > 0 ? dockScrubber : persistentScrubber
			itemViewWithMouseOver = itemView(at: location, in: scrubber)
			itemViewWithMouseOver?.set(isMouseOver: true)
			return
		}
		showCursor(at: location)
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseClickAtLocation location: NSPoint?) {
		guard Defaults[.showCursor] else {
			let adjustedLocation = dockScrubber.contentSize.width - (location?.x ?? 0)
			let scrubber		 = adjustedLocation > 0 ? dockScrubber : persistentScrubber
			launchItem(self.item(at: location, in: scrubber))
			return
		}
		guard let id = (cachedDockItemViews.first(where: { $0.value == itemViewWithMouseOver }) ?? cachedPersistentItemViews.first(where: { $0.value == itemViewWithMouseOver }))?.key,
			  let item = dockItems.first(where: { $0.diffId == id }) ?? persistentItems.first(where: { $0.diffId == id }) else {
			return
		}
		launchItem(item)
	}
}
