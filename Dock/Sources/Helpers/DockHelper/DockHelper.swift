//
//  DockHelper.swift
//  Dock
//
//  Created by Pierluigi Galdi on 28/12/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import AXSwift

public class DockHelper {
	
	/// Core
	private let dockApp: Application
	
	/// Data
	public private(set) var allTiles: [DockTile] = []
	
	public var applicationTiles: [DockApplicationTile] {
		return allTiles.filter { $0.role == .application }.map { $0 as! DockApplicationTile }
	}
	
	public var persistentTiles: [DockPersistentTile] {
		return allTiles.filter { $0.role != .application }.map { $0 as! DockPersistentTile }
	}
	
	/// Singleton
	public static let `default`: DockHelper = DockHelper()
	
	/// Initialiser
	private init() {
		guard let app = Application.allForBundleID("com.apple.dock").first else {
			fatalError("[DockWidget]: Can't instantiate `DockHelper` without running `com.apple.dock` (Dock).")
		}
		self.dockApp = app
		self.reloadAllDockItems()
	}
	
	/// Load data
	public func reloadAllDockItems(_ completion: (([DockTile]) -> Void)? = nil) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else {
				return
			}
			self.allTiles.removeAll()
			for element in self.dockApp.allChildrens() {
				guard element.optionalRole == "AXDockItem", let path = element.path else {
					guard element.optionalSubrole == "AXTrashDockItem", let title = element.title else {
						continue
					}
					let item = DockPersistentTile(role: .trash, title: title, path: URL(fileURLWithPath: Constants.trashPath))
					self.allTiles.append(item)
					continue
				}
				guard let title = element.title else {
					continue
				}
				if element.optionalSubrole == "AXApplicationDockItem" {
					guard let bid = element.bundleIdentifier else {
						continue
					}
					let badge = element.badge
					let pid	  = element.pid
					let item = DockApplicationTile(title: title, path: path, bundleIdentifier: bid, badge: badge, pid: pid, state: .terminated)
					self.allTiles.append(item)
				}else {
					guard let role: DockTileRole = {
						switch element.optionalSubrole {
						case "AXDocumentDockItem":
							return .document
						case "AXFolderDockItem":
							return .folder
						default:
							return nil
						}
					}() else {
						continue
					}
					let item = DockPersistentTile(role: role, title: title, path: path)
					self.allTiles.append(item)
				}
			}
			completion?(self.allTiles)
		}
	}
	
}

// MARK: AXSwift helpers
fileprivate extension UIElement {
	
	var optionalRole: String? {
		return value(for: .role)
	}
	
	var optionalSubrole: String? {
		return value(for: .subrole)
	}
	
	var title: String? {
		return value(for: .title)
	}
	
	var path: URL? {
		return value(for: .url)
	}
	
	var badge: String? {
		return value(for: "AXStatusLabel")
	}
	
	var pid: pid_t {
		return runningApp?.processIdentifier ?? 0
	}
	
	var isApplication: Bool {
		return optionalSubrole == "AXApplicationDockItem"
	}
	
	var bundleIdentifier: String? {
		guard let id = runningApp?.bundleIdentifier else {
			guard let path = path?.relativePath else {
				return nil
			}
			return Bundle(path: path)?.bundleIdentifier
		}
		return id
	}
	
	var runningApp: NSRunningApplication? {
		return NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == path })
	}
	
	func list<T>(for attribute: Attribute, of type: T.Type = T.self) -> [T] {
		guard let list = try? getMultipleAttributes(attribute).first?.value as? NSArray else {
			return []
		}
		return (list as? [T]) ?? []
	}
	
	func allChildrens() -> [UIElement] {
		let elements: [AXUIElement] = list(for: .children)
		var returnable: [UIElement] = []
		for item in elements {
			let elem = UIElement(item)
			if (try? elem.role()) == .list {
				returnable.append(contentsOf: elem.allChildrens())
			}else {
				returnable.append(elem)
			}
		}
		return returnable
	}
	
	/// Retrieve value for given attribute
	func value<T>(for attribute: Attribute?, of type: T.Type = T.self) -> T? {
		guard let attribute = attribute, let data = try? getMultipleAttributes(attribute) else {
			return nil
		}
		return data[attribute] as? T
	}
	
	func value<T>(for attribute: String, of type: T.Type = T.self) -> T? {
		guard let data = try? getMultipleAttributes([attribute]) else {
			return nil
		}
		return data[attribute] as? T
	}

}
