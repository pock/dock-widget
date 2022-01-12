//
//  AppExposeController.swift
//  Pock
//
//  Created by Pierluigi Galdi on 07/07/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import PockKit

class AppExposeController: PKTouchBarMouseController {
    
    /// UI
    @IBOutlet private weak var appName:      NSTextField!
    @IBOutlet private weak var windowsCount: NSTextField!
    @IBOutlet private weak var scrubber:     NSScrubber!
    
    /// Core
    private var dockRepository: DockRepository!
    private var app: NSRunningApplication!
    private var elements: [AppExposeItem] = []
	
	/// Mouse stuff
	private var itemViewWithMouseOver: AppExposeItemView?
	private var buttonWithMouseOver:   NSButton?
	private var touchBarView: NSView {
		if let view = scrubber.superview(subclassOf: Constants.NSTouchBarView) {
			return view
		}
		return scrubber
	}
	
	override var visibleRectWidth: CGFloat {
		get {
			return touchBarView.visibleRect.width
		}
		set { /**/ }
	}
	
	override var parentView: NSView! {
		get {
			return touchBarView
		}
		set { /**/ }
	}
    
    override func present() {
        guard app != nil else { return }
        super.present()
        self.setAppName(name: app.localizedName ?? "<missing name>")
    }
    
    override func didLoad() {
        scrubber?.register(AppExposeItemView.self, forItemIdentifier: Constants.kAppExposeItemView)
    }
    
    @IBAction func willClose(_ button: NSButton?) {
		edgeController?.tearDown(invalidate: true)
        navigationController?.popToRootController()
    }
    
	// MARK: Mouse stuff
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseEnteredAtLocation location: NSPoint, in view: NSView) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		super.screenEdgeController(controller, mouseEnteredAtLocation: location, in: view)
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseScrollWithDelta delta: CGFloat, atLocation location: NSPoint, in view: NSView) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		scrubber.scroll(with: delta)
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseClickAtLocation location: NSPoint, in view: NSView) {
		/// Check for button
		if let button = button(at: location) {
			willClose(button)
			return
		}
		guard let itemView = itemViewWithMouseOver, let item = elements.first(where: { $0.wid == itemView.wid }) else {
			return
		}
		handleItem(item)
	}
	
	override func updateCursorLocation(_ location: NSPoint?) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		itemViewWithMouseOver = nil
		super.updateCursorLocation(location)
		itemViewWithMouseOver = itemView(at: location)
		itemViewWithMouseOver?.set(isMouseOver: true)
		updateButtonWithMouseOverHilight(location)
	}
	
	private func updateButtonWithMouseOverHilight(_ location: NSPoint?) {
		buttonWithMouseOver?.isHighlighted = false
		buttonWithMouseOver = nil
		buttonWithMouseOver = button(at: location)
		buttonWithMouseOver?.isHighlighted = true
	}
	
}

extension AppExposeController {
    public func set(elements: [AppExposeItem]) {
        self.elements = elements
        self.windowsCount.stringValue = "\(elements.count) " + "windows".localized
        self.scrubber.reloadData()
		if elements.isEmpty == false {
			self.scrubber.scrollItem(at: 0, to: .none)
		}
		DispatchQueue.main.async { [weak self] in
			self?.reloadScreenEdgeController()
		}
    }
    public func set(app: NSRunningApplication) {
        self.app = app
    }
    private func setAppName(name: String?) {
        self.appName.stringValue = name ?? "Unknown".localized
    }
}

extension AppExposeController: NSScrubberDataSource {
    func numberOfItems(for scrubber: NSScrubber) -> Int {
        return elements.count
    }
    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let item = elements[index]
        let icon = item.minimized ? app.icon : item.preview
        let scaling: NSImageScaling = item.minimized ? .scaleProportionallyUpOrDown : .scaleAxesIndependently
        let view = scrubber.makeItem(withIdentifier: Constants.kAppExposeItemView, owner: self) as! AppExposeItemView
		view.wid = item.wid
		view.set(preview: icon, imageScaling: scaling)
        view.set(name: item.name)
        view.set(minimized: item.minimized)
        return view
    }
}

extension AppExposeController: NSScrubberFlowLayoutDelegate {
    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        return NSSize(width: 80, height: 30)
    }
}

extension AppExposeController: NSScrubberDelegate {
    func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
        handleItem(elements[selectedIndex])
    }
	private func handleItem(_ item: AppExposeItem) {
		let helper = PockDockHelper()
		helper.activate(item, in: app)
		if item.minimized {
			helper.activate(item, in: app)
		}else if helper.windowIsFrontmost(item.wid, forApp: app) {
			// TODO: PockDockHelper.sharedInstance()?.minimizeWindowItem(item)
		}
		willClose(nil)
	}
}

extension AppExposeController {
	private func itemView(at location: NSPoint?) -> AppExposeItemView? {
		guard let scrubber = scrubber else {
			return nil
		}
		return scrubber.subview(in: parentView, at: location, of: AppExposeItemView.self)
	}
	
	private func button(at location: NSPoint?) -> NSButton? {
		guard let view = parentView.subview(in: parentView, at: location, of: Constants.NSTouchBarItemContainerView) else {
			return nil
		}
		return view.findViews(subclassOf: NSButton.self).first
	}
}
