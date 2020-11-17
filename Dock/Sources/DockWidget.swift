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
		return min(dockContentSize + persistentContentSize, max)
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
			self.screenEdgeController = ScreenEdgeController(delegate: self)
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
	
	private func showCursor(at location: NSPoint?) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		guard let location = location else {
			cursorView?.removeFromSuperview()
			cursorView = nil
			return
		}
		if Defaults[.showCursor] {
			if cursorView == nil {
				cursorView = NSImageView(image: NSCursor.arrow.image)
				view.addSubview(cursorView!)
			}
			cursorView?.frame = NSRect(x: location.x, y: location.y, width: 20, height: 20)
		}
		itemViewWithMouseOver = itemView(at: location)
		itemViewWithMouseOver?.set(isMouseOver: true)
	}
	
	private func item(at location: NSPoint) -> DockItem? {
		let loc = NSPoint(x: location.x + 6, y: 12)
		guard let result = cachedDockItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
			guard let result = cachedPersistentItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
				return nil
			}
			return persistentItems.first(where: { $0.diffId == result.key })
		}
		return dockItems.first(where: { $0.diffId == result.key })
	}
	
	private func itemView(at location: NSPoint) -> DockItemView? {
		let loc = NSPoint(x: location.x + 6, y: 12)
		guard let result = cachedDockItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
			guard let result = cachedPersistentItemViews.first(where: { $0.value.convert($0.value.iconView.frame, to: self.view).contains(loc) }) else {
				return nil
			}
			return result.value
		}
		return result.value
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseMovedAtLocation location: NSPoint?) {
		showCursor(at: location)
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseScrollWithDelta delta: CGFloat) {
		guard Defaults[.showCursor] else {
			return
		}
		itemViewWithMouseOver?.set(isMouseOver: false)
		print("[DockWidget]: SCROLL delta: \(delta)")
	}
	
	func screenEdgeController(_ controller: ScreenEdgeController, mouseClickAtLocation location: NSPoint) {
		launchItem(item(at: location))
	}
}
