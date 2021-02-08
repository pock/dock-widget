//
//  DockFolderController.swift
//  Pock
//
//  Created by Pierluigi Galdi on 04/05/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import PockKit
import Defaults

class DockFolderController: PKTouchBarMouseController {
    
    /// UI
	@IBOutlet private weak var closeButton:  NSButton!
    @IBOutlet private weak var folderName:   NSTextField!
    @IBOutlet private weak var folderDetail: NSTextField!
    @IBOutlet private weak var scrubber:     NSScrubber!
	@IBOutlet private weak var backButton:   NSButton!
	@IBOutlet private weak var openButton:	 NSButton!
    
    /// Core
    private var dockFolderRepository: DockFolderRepository!
    private var folderUrl: URL!
    private var elements: [DockFolderItem] = []
	
	private var itemViewWithMouseOver: DockFolderItemView?
	private var buttonWithMouseOver:   NSButton?
	private var touchBarView: NSView {
		if let view = scrubber.superview(subclassOf: Constants.NSTouchBarView) {
			return view
		}
		fatalError("Can't find NSTouchBarView object.")
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
        guard folderUrl != nil else { return }
        if !folderUrl.absoluteString.contains("file://") {
            folderUrl = URL(string: "file://\(folderUrl.absoluteString)")
        }
        self.loadElements()
        var defaultIdentifiers = touchBar?.defaultItemIdentifiers
        if !dockFolderRepository.shouldShowBackButton {
            defaultIdentifiers?.removeAll(where: { $0.rawValue == "BackButton" })
        }
        touchBar?.defaultItemIdentifiers = defaultIdentifiers ?? []
        super.present()
        self.setCurrentFolder(name: folderUrl?.lastPathComponent ?? "<missing name>")
        self.folderDetail.stringValue = "Loading...".localized
    }
    
    override func didLoad() {
        super.didLoad()
        scrubber.register(DockFolderItemView.self, forItemIdentifier: Constants.kDockFolterItemView)
    }
    
    @IBAction func willClose(_ button: NSButton?) {
        dockFolderRepository.popToRootDockFolderController()
    }
    
    @IBAction func willDismiss(_ button: NSButton?) {
		dockFolderRepository.popDockFolderController()
    }
    
    @IBAction func willOpen(_ button: NSButton?) {
        NSWorkspace.shared.open(folderUrl)
        willClose(nil)
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
			switch button {
			case backButton:
				willDismiss(button)
			case openButton:
				willOpen(button)
			case closeButton:
				willClose(button)
			default:
				break
			}
			return
		}
		guard let itemView = itemViewWithMouseOver, let item = elements.first(where: { $0.diffId == itemView.index }) else {
			return
		}
		open(item: item)
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

extension DockFolderController {
    public func set(folderUrl: URL) {
        self.folderUrl = folderUrl
    }
    public func set(dockFolderRepository: DockFolderRepository) {
        self.dockFolderRepository = dockFolderRepository
    }
}

extension DockFolderController {
    private func loadElements(reloadScrubber: Bool = true) {
        dockFolderRepository.getItems(in: folderUrl) { [weak self] elements in
            self?.elements = elements
            self?.folderDetail?.stringValue = "\(elements.count) " + "elements".localized
            if reloadScrubber {
				self?.scrubber.reloadData()
				if elements.isEmpty == false {
					self?.scrubber.scrollItem(at: 0, to: .none)
				}
			}
        }
    }
    private func setCurrentFolder(name: String) {
        self.folderName.stringValue = name == ".Trash" ? "Trash".localized : name.truncate(length: 30)
    }
}

extension DockFolderController: NSScrubberDataSource {
    func numberOfItems(for scrubber: NSScrubber) -> Int {
        return elements.count
    }
    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let item = elements[index]
        let view = scrubber.makeItem(withIdentifier: Constants.kDockFolterItemView, owner: self) as! DockFolderItemView
		view.index = item.diffId
        view.set(icon:   item.icon)
        view.set(name:   item.name)
        view.set(detail: item.detail)
        return view
    }
}

extension DockFolderController: NSScrubberFlowLayoutDelegate {
    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        let item = elements[itemIndex]
        let font = NSFont.systemFont(ofSize: 10)
        let w = max(width(for: item.name?.truncate(length: 20), with: font), width(for: item.detail?.truncate(length: 20), with: font))
        return NSSize(width: w, height: 30)
    }
    private func width(for text: String?, with font: NSFont) -> CGFloat {
        let fontAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font]
        let size = (text ?? "").size(withAttributes: fontAttributes)
        return max(30, Constants.dockItemIconSize.width + 8 + size.width)
    }
}

extension DockFolderController: NSScrubberDelegate {
    func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
        open(item: elements[selectedIndex])
        scrubber.selectedIndex = -1
    }
	private func open(item: DockFolderItem?) {
		guard let item = item else {
			return
		}
		dockFolderRepository.open(item: item) { success in
			print("[DockWidget][DockFolderController]: Did open: \(item.path?.path ?? "<unknown>") [success: \(success)]")
		}
	}
}

extension DockFolderController {
	private func itemView(at location: NSPoint?) -> DockFolderItemView? {
		guard let scrubber = scrubber else {
			return nil
		}
		return scrubber.subview(in: parentView, at: location, of: DockFolderItemView.self)
	}
	
	private func button(at location: NSPoint?) -> NSButton? {
		guard let view = parentView.subview(in: parentView, at: location, of: Constants.NSTouchBarItemContainerView) else {
			return nil
		}
		return view.findViews(subclassOf: NSButton.self).first
	}
}
