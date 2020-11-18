//
//  DraggingInfoView.swift
//  Pock
//
//  Created by Pierluigi Galdi on 11/18/2020.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import Foundation
import PockKit

public class DraggingInfoView: NSView {
	convenience init(filepath: URL) {
		self.init(frame: .zero)
		self.wantsLayer = true
		self.layer?.backgroundColor = NSColor.clear.cgColor
		setupImageView(for: filepath)
		let nameLabel = setupNameLabel(for: filepath)
		self.frame.size = NSSize(width: nameLabel.frame.origin.x + nameLabel.frame.width, height: 15)
	}
	private func setupImageView(for filepath: URL) {
		let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 20, height: 15))
		imageView.image = DockRepository.getIcon(forBundleIdentifier: nil, orPath: filepath.relativePath, orType: nil)
		addSubview(imageView)
	}
	private func setupNameLabel(for filepath: URL) -> NSView {
		let container = NSView(frame: .zero)
		container.wantsLayer = true
		container.layer?.backgroundColor = NSColor.systemBlue.cgColor
		container.layer?.cornerRadius = 7.5
		container.layer?.masksToBounds = false
		let nameLabel = ScrollingTextView(frame: .zero)
		nameLabel.numberOfLoop = 1
		nameLabel.textColor    = .white
		nameLabel.font 		   = NSFont.systemFont(ofSize: 9)
		nameLabel.frame 	   = NSRect(x: 6, y: 0, width: 0, height: 15)
		nameLabel.setup(string: filepath.lastPathComponent)
		nameLabel.frame.size.width = min(200, nameLabel.stringSize.width)
		nameLabel.speed	= nameLabel.stringSize.width > 200 ? 4 : 0
		container.addSubview(nameLabel)
		container.frame = NSRect(x: 20, y: 0, width: nameLabel.frame.width + 12, height: 15)
		addSubview(container)
		return container
	}
}
