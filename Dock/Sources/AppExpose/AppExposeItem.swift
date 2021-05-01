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
		self.mouseOverView = NSView(frame: .zero)
		self.mouseOverView.wantsLayer = true
		self.mouseOverView.layer?.masksToBounds = true
		self.mouseOverView.layer?.cornerRadius = 2
		self.contentView.addSubview(self.mouseOverView, positioned: .below, relativeTo: self.preview)
		self.mouseOverView.edgesToSuperview()
	}
	
    /// Load preview view
    private func loadPreviewView() {
        self.preview = NSImageView(frame: .zero)
        self.preview.wantsLayer = true
        self.contentView.addSubview(self.preview)
		self.preview.topToSuperview()
		self.preview.leftToSuperview()
		self.preview.rightToSuperview()
    }
    
    /// Load name label
    private func loadNameLabel() {
        nameLabel = ScrollingTextView(frame: .zero)
        nameLabel.numberOfLoop = 1
        nameLabel.autoresizingMask = .none
        nameLabel.font = NSFont.systemFont(ofSize: 6)
        contentView.addSubview(nameLabel)
		nameLabel.width(72)
		nameLabel.height(6)
		nameLabel.leftToSuperview(offset: -4)
		nameLabel.rightToSuperview(offset: -4)
		nameLabel.top(to: preview, preview.bottomAnchor)
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
        self.set(name:    nil)
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
		mouseOverView.layer?.backgroundColor = (isMouseOver ? NSColor.darkGray : NSColor.clear).cgColor
	}
	
}
