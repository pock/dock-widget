//
//  DockFolderController.swift
//  Pock
//
//  Created by Pierluigi Galdi on 04/05/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import PockKit

class DockFolderController: PKTouchBarMouseController {
    
    /// UI
    @IBOutlet private weak var folderName:   NSTextField!
    @IBOutlet private weak var folderDetail: NSTextField!
    @IBOutlet private weak var scrubber:     NSScrubber!
    
    /// Core
    private var dockFolderRepository: DockFolderRepository!
    private var folderUrl: URL!
    private var elements: [DockFolderItem] = []
	
	private var itemViewWithMouseOver: DockFolderItemView?
	
	override var parentView: NSView! {
		get {
			return scrubber
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
        scrubber.register(DockFolderItemView.self, forItemIdentifier: Constants.kDockFolterItemView)
    }
    
    @IBAction func willClose(_ button: NSButton?) {
		edgeController?.tearDown(invalidate: true)
        dockFolderRepository.popToRootDockFolderController()
    }
    
    @IBAction func willDismiss(_ button: NSButton?) {
		edgeController?.tearDown(invalidate: true)
		dockFolderRepository.popDockFolderController()
    }
    
    @IBAction func willOpen(_ button: NSButton?) {
        NSWorkspace.shared.open(folderUrl)
        willClose(nil)
    }
	
	// MARK: Mouse stuff
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseEnteredAtLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		super.screenEdgeController(controller, mouseEnteredAtLocation: location)
	}
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseScrollWithDelta delta: CGFloat, atLocation location: NSPoint) {
		itemViewWithMouseOver?.set(isMouseOver: false)
		guard let clipView:   NSClipView   = scrubber.findViews().first,
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
	
	override func screenEdgeController(_ controller: PKScreenEdgeController, mouseClickAtLocation location: NSPoint) {
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
				self?.reloadScreenEdgeController()
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
		guard let location = location, let scrubber = scrubber else {
			return nil
		}
		let loc = NSPoint(x: location.x, y: 12)
		let views: [DockFolderItemView] = scrubber.findViews()
		return views.first(where: { $0.superview?.convert($0.frame, to: parentView).contains(loc) == true })
	}
}
