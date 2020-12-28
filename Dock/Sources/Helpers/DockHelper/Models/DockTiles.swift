//
//  DockTiles.swift
//  Dock
//
//  Created by Pierluigi Galdi on 28/12/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

// MARK: DockTileRole
public enum DockTileRole {
	case application, document, folder, trash
}

// MARK: DockTile (Common)
public protocol DockTile {
	var role:  DockTileRole { get set }
	var title: String { get set }
	var path:  URL { get set }
}

// MARK: Persistent
public class DockPersistentTile: DockTile {
	
	/// Data
	public var role:  DockTileRole
	public var title: String
	public var path:  URL
	
	/// Initialiser
	public init(role: DockTileRole, title: String, path: URL) {
		self.role = role
		self.title = title
		self.path = path
	}
	
}

// MARK: Application
public class DockApplicationTile: DockTile {

	/// Running state
	public enum State {
		case running, bouncing, terminated
	}
	
	/// Data
	public var role:  DockTileRole
	public var title: String
	public var path:  URL
	public var bundleIdentifier: String
	public var badge: 			 String?
	public var pid: 			 pid_t
	public var state:		 	 State
	
	/// Initialiser
	public init(title: String, path: URL, bundleIdentifier: String, badge: String?, pid: pid_t, state: State) {
		self.role			  = .application
		self.title			  = title
		self.path			  = path
		self.bundleIdentifier = bundleIdentifier
		self.badge 			  = badge
		self.pid 			  = pid
		self.state 			  = state
	}
	
}
