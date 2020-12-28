//
//  Constants.swift
//  Pock
//
//  Created by Pierluigi Galdi on 06/04/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Defaults

class Constants {
    /// Known identifiers
    static let kFinderIdentifier: 	 String = "com.apple.finder"
	static let kLaunchpadIdentifier: String = "com.apple.launchpad.launcher"
    /// Known paths
    static let dockPlist = NSHomeDirectory().appending("/Library/Preferences/com.apple.dock.plist")
    static let trashPath = NSHomeDirectory().appending("/.Trash")
    /// UI
    static let dockItemSize:            NSSize  = NSSize(width: 40, height: 30)
	static var dockItemIconSize:        NSSize {
		let val = Defaults[.hideRunningIndicator] ? 27 : 24
		return NSSize(width: val, height: val)
	}
	static var dockItemDotSize:         NSSize {
		return Defaults[.hideRunningIndicator] ? .zero : NSSize(width: 3,  height: 3)
	}
    static let dockItemBadgeSize:       NSSize  = NSSize(width: 10, height: 10)
    static let dockItemCornerRadius:    CGFloat = 6
    static let dockItemBounceThreshold: CGFloat = 10
    /// Keys
    static let kDockItemView:       NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier(rawValue: "kDockItemView")
    static let kDockFolterItemView: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier(rawValue: "kDockFolterItemView")
    static let kAppExposeItemView:  NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier(rawValue: "kAppExposeItemView")
    static let kBounceAnimation:    String = "kBounceAnimation"
}

extension NSScrubber {
	internal var contentSize: NSSize {
		return scrubberLayout.scrubberContentSize
	}
	internal func scroll(with delta: CGFloat) {
		guard let clipView:   NSClipView   = findViews().first,
			  let scrollView: NSScrollView = findViews().first else {
			return
		}
		let maxWidth = contentSize.width - visibleRect.width
		let newX     = clipView.bounds.origin.x - delta
		if maxWidth > 0, (-6...maxWidth+6).contains(newX) {
			clipView.setBoundsOrigin(NSPoint(x: newX, y: clipView.bounds.origin.y))
			scrollView.reflectScrolledClipView(clipView)
		}
	}
}

extension NSView {
	func findViews<T: NSView>(subclassOf: T.Type = T.self) -> [T] {
		return recursiveSubviews.compactMap { $0 as? T }
	}
	var recursiveSubviews: [NSView] {
		return subviews + subviews.flatMap { $0.recursiveSubviews }
	}
}
