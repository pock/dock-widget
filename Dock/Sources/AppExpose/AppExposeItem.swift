//
//  AppExposeItem.swift
//  Pock
//
//  Created by Pierluigi Galdi on 07/07/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Cocoa
import PockKit

typealias AppExposeItem = CGWindowItem

class AppExposeItemView: NSScrubberItemView {
    
    /// UI
	public  var wid: CGWindowID!
    private var contentView:    NSView!
	private var mouseOverView:  NSView!
    private var preview:        NSImageView!
    private var nameLabel:      ScrollingTextView!
    
	/// Load mouseover view
	private func loadMouseOverView() {
		mouseOverView = NSView(frame: .zero)
		mouseOverView.wantsLayer = true
		mouseOverView.layer?.masksToBounds = true
		mouseOverView.layer?.cornerRadius = 1
		preview.addSubview(mouseOverView)
		mouseOverView.edgesToSuperview()
	}
	
    /// Load preview view
    private func loadPreviewView() {
        preview = NSImageView(frame: .zero)
        preview.wantsLayer = true
        contentView.addSubview(preview)
		preview.topToSuperview()
		preview.leftToSuperview()
		preview.rightToSuperview()
    }
    
    /// Load name label
    private func loadNameLabel() {
        nameLabel = ScrollingTextView(frame: .zero)
        nameLabel.numberOfLoop = 1
        nameLabel.autoresizingMask = .none
        nameLabel.font = NSFont.systemFont(ofSize: 6)
        contentView.addSubview(nameLabel)
		nameLabel.height(6)
		nameLabel.left(to: preview, offset: 2)
		nameLabel.right(to: preview, offset: 2)
		nameLabel.topToBottom(of: preview, offset: 1)
		nameLabel.bottomToSuperview()
    }
    
    /// Init
    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: Constants.dockItemSize))
        self.contentView = NSView(frame: .zero)
        self.loadPreviewView()
        self.loadNameLabel()
        self.addSubview(self.contentView)
		self.contentView.edgesToSuperview()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.set(preview: nil, imageScaling: .scaleAxesIndependently)
        self.set(name: nil)
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale                = window?.backingScaleFactor ?? 1
        preview?.layer?.contentsScale      = window?.backingScaleFactor ?? 1
    }
    
    public func set(preview: NSImage?, imageScaling: NSImageScaling) {
        self.preview.imageScaling = imageScaling
        self.preview.image = preview
    }
    
    public func set(name: String?) {
        let size = ((name ?? "") as NSString).size(withAttributes: nameLabel.textFontAttributes).width
        nameLabel.speed = size > 80 ? 4 : 0
        nameLabel.setup(string: name ?? "")
    }
    
    public func set(minimized: Bool) {
        preview.layer?.opacity = minimized ? 0.4 : 1
    }
    
	public func set(isMouseOver: Bool) {
		if mouseOverView == nil { loadMouseOverView() }
		mouseOverView.layer?.backgroundColor = (isMouseOver ? NSColor.white.withAlphaComponent(0.325) : NSColor.clear).cgColor
	}
	
}
