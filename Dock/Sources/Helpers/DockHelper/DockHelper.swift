//
//  DockHelper.swift
//  Dock
//
//  Created by Pierluigi Galdi on 28/12/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

// MARK: Dock presentation mode

internal enum DockMode {
	case hidden, visible, disabled
	var string: String {
		switch self {
		case .hidden:
			return "Hidden"
		case .visible:
			return "Visible"
		case .disabled:
			return "Disabled"
		}
	}
	var autohide: Bool {
		switch self {
		case .hidden:
			return true
		case .visible:
			return false
		case .disabled:
			return true
		}
	}
	var autohide_delay: CGFloat? {
		switch self {
		case .hidden, .visible:
			return nil
		case .disabled:
			return 999999
		}
	}
}

fileprivate let kAutoHideDelay 	= "autohide-delay" as CFString
fileprivate let kAutoHide 		= "autohide" 	   as CFString
fileprivate let kDockIdentifier = "com.apple.dock" as CFString

public class DockHelper {
	
	static var currentMode: DockMode {
		if CFPreferencesCopyAppValue(kAutoHideDelay, kDockIdentifier) as? CGFloat ?? 0 >= 999999 {
			return .disabled
		}
		return CoreDockGetAutoHideEnabled() ? .hidden : .visible
	}
	
	@discardableResult
	static func setDockMode(_ newMode: DockMode) -> Bool {
		let previousMode = self.currentMode
		guard previousMode != newMode else {
			return false
		}
		CoreDockSetAutoHideEnabled(newMode.autohide)
		CFPreferencesSetAppValue(kAutoHideDelay, newMode.autohide_delay as CFNumber?, kDockIdentifier)
		let result = CFPreferencesAppSynchronize(kDockIdentifier)
		if previousMode == .disabled || newMode.autohide_delay != nil {
			reloadSystemDock()
		}
		return result
	}
	
	private static func reloadSystemDock() {
		let task = Process()
		task.launchPath = "/usr/bin/pkill"
		task.arguments = ["Dock"]
		let pipe = Pipe()
		task.standardOutput = pipe
		task.launch()
	}
	
}
