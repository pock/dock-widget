//
//  DockRepository.swift
//  Dock
//
//  Created by Pierluigi Galdi on 21/11/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

protocol DockDelegate: AnyObject {
	func didUpdateDockItem(_ item: DockItem, at index: Int, terminated: Bool, isDefaults: Bool)
	func didUpdateActiveItem(_ item: DockItem, at index: Int, activated: Bool)
	func didUpdatePersistentItem(_ item: DockItem, at index: Int, added: Bool)
	func didUpdateBadge(for apps: [DockItem])
}

class DockRepository {
	
	/// Delegate
	private weak var dockDelegate: DockDelegate?
	
	/// Core
	private var fileMonitor: FileMonitor!
	private var notificationBadgeRefreshTimer: Timer!
	private var shouldShowNotificationBadge: Bool {
		let refreshInterval: NotificationBadgeRefreshRateKeys = Preferences[.notificationBadgeRefreshInterval]
		return refreshInterval != .never
	}
	private var showOnlyRunningApps: Bool { return Preferences[.showOnlyRunningApps] }
	private var openFinderInsidePock: Bool { return Preferences[.openFinderInsidePock] }
	private var dockFolderRepository: DockFolderRepository?
	private var keyValueObservers: [NSKeyValueObservation] = []
	
	/// Data
	private var defaultItems: [DockItem] 	= []
	private var runningItems: [DockItem] 	= []
	private var persistentItems: [DockItem] = []
	private var dockItems: [DockItem] {
		if Preferences[.showOnlyRunningApps] {
			return self.runningItems
		}
		return runningItems + defaultItems.filter({ runningItems.contains($0) == false })
	}
	
	/// Default initialiser
	init(delegate: DockDelegate) {
		self.dockDelegate = delegate
		self.dockFolderRepository = DockFolderRepository()
		self.registerForEventsAndNotifications()
		self.setupNotificationBadgeRefreshTimer()
		self.reloadDockItems(nil)
	}
	
	/// Deinit
	deinit {
		self.notificationBadgeRefreshTimer?.invalidate()
		self.unregisterFromEventsAndNotifications()
		dockFolderRepository = nil
		defaultItems.removeAll()
		runningItems.removeAll()
		persistentItems.removeAll()
	}
	
	/// Update notification badge refresh timer
	@objc private func setupNotificationBadgeRefreshTimer() {
		/// Get refresh rate
		let refreshRate: NotificationBadgeRefreshRateKeys = Preferences[.notificationBadgeRefreshInterval]
		/// Invalidate last timer
		self.notificationBadgeRefreshTimer?.invalidate()
		/// Check if disabled
		guard refreshRate.rawValue >= 0 else {
			return
		}
		/// Set timer for fetching badges
		self.notificationBadgeRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshRate.rawValue, repeats: true, block: {  [weak self] _ in
			DispatchQueue.main.async { [weak self] in
				self?.updateNotificationBadges()
			}
		})
	}
	
}

// MARK: Register/Unregister from event and notifications
extension DockRepository {
	
	/// Register for events and notifications
	private func registerForEventsAndNotifications() {
		registerForRunningAppsEvents()
		registerForWorkspaceNotifications()
		registerForInternalNotifications()
		fileMonitor = FileMonitor(paths: [Constants.trashPath, Constants.dockPlist], delegate: self)
	}
	
	/// Unregister from events and notifications
	private func unregisterFromEventsAndNotifications() {
		fileMonitor = nil
		keyValueObservers.forEach { $0.invalidate() }
		keyValueObservers.removeAll()
		NSWorkspace.shared.notificationCenter.removeObserver(self)
	}
	
	// MARK: Events
	private func registerForRunningAppsEvents() {
		self.keyValueObservers = [
			NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new], changeHandler: { [weak self] _, change in
				if let apps = change.newValue {
					for app in apps {
						self?.updateRunningState(for: app, wasLaunched: true)
					}
				}else if let apps = change.oldValue {
					for app in apps {
						self?.updateRunningState(for: app, wasTerminated: true)
					}
				}else {
					self?.loadRunningItems()
				}
			})
		]
	}
	
	// MARK: Notifications
	private func registerForWorkspaceNotifications() {
		NSWorkspace.shared.notificationCenter.addObserver(self,
														  selector: #selector(updateActiveState(_:)),
														  name: NSWorkspace.didActivateApplicationNotification,
														  object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self,
														  selector: #selector(updateActiveState(_:)),
														  name: NSWorkspace.didDeactivateApplicationNotification,
														  object: nil)
	}
	
	private func registerForInternalNotifications() {
		NSWorkspace.shared.notificationCenter.addObserver(self,
														  selector: #selector(self.setupNotificationBadgeRefreshTimer),
														  name: .didChangeNotificationBadgeRefreshRate,
														  object: nil)
	}
	
}

// MARK: Load items
extension DockRepository {
	
	/// Reload
	@objc private func reloadDockItems(_ notification: NSNotification?) {
		loadRunningItems()
		loadDefaultItems()
		loadPersistentItems()
	}
	
	/// Running apps
	@objc private func loadRunningItems() {
		for app in NSWorkspace.shared.runningApplications {
			updateRunningState(for: app)
		}
	}
	
	/// Defaults
	@objc private func loadDefaultItems() {
		/// Read data from Dock plist
		guard let dict = UserDefaults.standard.persistentDomain(forName: "com.apple.dock") else {
			NSLog("[DockWidget]: Can't read Dock preferences file")
			return
		}
		/// Read persistent apps array
		guard let apps = dict["persistent-apps"] as? [[String: Any]] else {
			NSLog("[DockWidget]: Can't get persistent apps")
			return
		}
		/// Empty array
		defaultItems.removeAll(where: { item in self.runningItems.contains(where: { $0.bundleIdentifier == item.bundleIdentifier }) == false })
		/// Add Finder item, if needed
		if Preferences[.hideFinder] {
			if let item = defaultItems.first(where: { $0.bundleIdentifier == Constants.kFinderIdentifier }) {
				dockDelegate?.didUpdateDockItem(item, at: item.index, terminated: true, isDefaults: false)
				defaultItems.removeAll(where: { $0.diffId == item.diffId })
			}
		}else if defaultItems.contains(where: { $0.bundleIdentifier == Constants.kFinderIdentifier }) == false {
			let item = DockItem(0, Constants.kFinderIdentifier, name: "Finder", path: nil, icon: DockRepository.getIcon(forBundleIdentifier: Constants.kFinderIdentifier))
			defaultItems.insert(item, at: 0)
			dockDelegate?.didUpdateDockItem(item, at: 0, terminated: false, isDefaults: true)
		}
		/// Only running apps
		guard Preferences[.showOnlyRunningApps] == false else {
			for (index, item) in runningItems.enumerated() {
				dockDelegate?.didUpdateDockItem(item, at: index, terminated: false, isDefaults: false)
			}
			return
		}
		/// Iterate on apps
		for (index,app) in apps.enumerated() {
			/// Get data tile
			guard let dataTile = app["tile-data"] as? [String: Any] else {
				NSLog("[DockWidget]: Can't get app tile-data")
				continue
			}
			/// Get app's label
			guard let label = dataTile["file-label"] as? String else {
				NSLog("[DockWidget]: Can't get app label")
				continue
			}
			/// Get app's bundle identifier
			guard let bundleIdentifier = dataTile["bundle-identifier"] as? String else {
				NSLog("[DockWidget]: Can't get app bundle identifier")
				continue
			}
			/// Check if item already exists
			guard defaultItems.contains(where: { $0.bundleIdentifier == bundleIdentifier }) == false else {
				continue
			}
			/// Create item
			let item = DockItem(index + (Preferences[.hideFinder] ? 0 : 1),
								bundleIdentifier,
								name: label,
								path: nil,
								icon: DockRepository.getIcon(forBundleIdentifier: bundleIdentifier),
								pid_t: 0,
								launching: false)
			defaultItems.append(item)
			dockDelegate?.didUpdateDockItem(item, at: item.index, terminated: false, isDefaults: true)
		}
	}
	
	/// Load persistent folders and files
	@objc private func loadPersistentItems() {
		/// Read data from Dock plist
		guard let dict = UserDefaults.standard.persistentDomain(forName: "com.apple.dock") else {
			NSLog("[DockWidget]: Can't read Dock preferences file")
			return
		}
		/// Read persistent apps array
		guard let apps = dict["persistent-others"] as? [[String: Any]] else {
			NSLog("[DockWidget]: Can't get persistent apps")
			return
		}
		/// Temp array
		var tmpPersistentItems: [DockItem] = []
		/// Iterate on apps
		for (index,app) in apps.enumerated() {
			/// Get data tile
			guard let dataTile = app["tile-data"] as? [String: Any] else { NSLog("[DockWidget]: Can't get file tile-data"); continue }
			/// Get app's label
			guard let label = dataTile["file-label"] as? String else { NSLog("[DockWidget]: Can't get file label"); continue }
			/// Get file data
			guard let fileData = dataTile["file-data"] as? [String: Any] else { NSLog("[DockWidget]: Can't get file data"); continue }
			/// Get app's bundle identifier
			guard let path = fileData["_CFURLString"] as? String else { NSLog("[DockWidget]: Can't get file path"); continue }
			/// Create item
			let item = DockItem(index,
								nil,
								name: label,
								path: URL(string: path),
								icon: DockRepository.getIcon(orPath: path.replacingOccurrences(of: "file://", with: "")),
								launching: false,
								persistentItem: true)
			if persistentItems.contains(item) == false {
				persistentItems.append(item)
			}
			tmpPersistentItems.append(item)
			dockDelegate?.didUpdatePersistentItem(item, at: index, added: true)
		}
		///  Remove from current list
		for removedItem in persistentItems.enumerated().filter({ tmpPersistentItems.contains($0.element) == false }) {
			if removedItem.element.name == "Trash" {
				continue
			}
			persistentItems.remove(at: removedItem.offset)
			dockDelegate?.didUpdatePersistentItem(removedItem.element, at: removedItem.offset, added: false)
		}
		/// Handle Trash
		if Preferences[.hideTrash] {
			if let item = persistentItems.first(where: { $0.path?.absoluteString == Constants.trashPath }) {
				dockDelegate?.didUpdatePersistentItem(item, at: item.index, added: false)
				persistentItems.removeAll(where: { $0.diffId == item.diffId })
			}
		}else if persistentItems.contains(where: { $0.path?.absoluteString == Constants.trashPath }) == false {
			let trashType = ((try? FileManager.default.contentsOfDirectory(atPath: Constants.trashPath).isEmpty) ?? true) ? "TrashIcon" : "FullTrashIcon"
			let item = DockItem(
				self.persistentItems.count,
				nil,
				name: "Trash",
				path: URL(string: "file://"+Constants.trashPath)!,
				icon: DockRepository.getIcon(orType: trashType),
				persistentItem: true)
			persistentItems.append(item)
			dockDelegate?.didUpdatePersistentItem(item, at: item.index, added: true)
		}
	}
	
}

// MARK: Updates items
extension DockRepository {
	
	private var lastValidDockItemsIndex: Int {
		let count = self.dockItems.count
		guard count > 0 else {
			return 0
		}
		return count - 1
	}
	
	/// Create item
	private func createItem(for app: NSRunningApplication) -> DockItem? {
		/// Create `DockItem` object
		guard app.activationPolicy == .regular, let id = app.bundleIdentifier, id != Constants.kFinderIdentifier else {
			return nil
		}
		guard let localizedName = app.localizedName,
			  let bundleURL     = app.bundleURL,
			  let icon          = app.icon else {
			return nil
		}
		return DockItem(0, id, name: localizedName, path: bundleURL, icon: icon, pid_t: app.processIdentifier, launching: app.isFinishedLaunching == false)
	}
	
	/// Update running items
	private func updateRunningState(for app: NSRunningApplication, wasLaunched: Bool = false, wasTerminated: Bool = false) {
		guard app.activationPolicy == .regular else {
			return
		}
		DispatchQueue.main.async { [weak self, app] in
			guard let self = self else {
				return
			}
			/// Check from dock items
			guard let item = self.defaultItems.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
				guard let runningItem = self.runningItems.enumerated().first(where: { $0.element.bundleIdentifier == app.bundleIdentifier }) else {
					if let item = self.createItem(for: app) {
						self.runningItems.append(item)
						self.dockDelegate?.didUpdateDockItem(item, at: self.lastValidDockItemsIndex, terminated: false, isDefaults: false)
					}
					return
				}
				if wasTerminated {
					self.runningItems.remove(at: runningItem.offset)
					self.dockDelegate?.didUpdateDockItem(runningItem.element, at: self.lastValidDockItemsIndex, terminated: true, isDefaults: false)
				}
				return
			}
			item.name  = app.localizedName ?? item.name
			item.icon  = app.icon ?? item.icon
			item.pid_t = wasTerminated ? 0 : app.processIdentifier
			if let runningItemIndex = self.runningItems.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
				if wasTerminated {
					self.runningItems.remove(at: runningItemIndex)
				}
			}else {
				if wasLaunched {
					self.runningItems.append(item)
				}
			}
			self.dockDelegate?.didUpdateDockItem(item, at: self.lastValidDockItemsIndex, terminated: wasTerminated, isDefaults: true)
		}
		NSLog("[DockRepositoryEvo]: Update running state for app: [\(app.bundleIdentifier ?? "<unknown-app-\(app)>")]")
	}
	
	/// Update active state
	@objc private func updateActiveState(_ notification: NSNotification?) {
		DispatchQueue.main.async { [weak self, notification] in
			guard let self = self else {
				return
			}
			if let app = notification?.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
				if let result = self.dockItems.enumerated().first(where: { $0.element.bundleIdentifier == app.bundleIdentifier }) {
					result.element.isLaunching = false
					self.dockDelegate?.didUpdateActiveItem(result.element, at: result.offset, activated: notification?.name == NSWorkspace.didActivateApplicationNotification)
				}
			}
		}
	}

}

// MARK: App icon's badge
extension DockRepository {
	/// Load notification badges
	private func updateNotificationBadges() {
		guard shouldShowNotificationBadge, let delegate = self.dockDelegate else {
			return
		}
		for item in dockItems {
			item.badge = PockDockHelper().getBadgeCountForItem(withName: item.name)
		}
		delegate.didUpdateBadge(for: self.dockItems)
	}
}

// MARK: File Monitor Delegate
extension DockRepository: FileMonitorDelegate {
	func didChange(fileMonitor: FileMonitor, paths: [String]) {
		loadPersistentItems()
	}
}

// MARK: Get app/file icon
extension DockRepository {
	/// Get icon
	public class func getIcon(forBundleIdentifier bundleIdentifier: String? = nil, orPath path: String? = nil, orType type: String? = nil) -> NSImage? {
		/// Check for bundle identifier first
		if bundleIdentifier != nil {
			/// Get app's absolute path
			if let appPath = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleIdentifier!) {
				/// Return icon
				return NSWorkspace.shared.icon(forFile: appPath)
			}
		}
		/// Then check for path
		if let path = path?.removingPercentEncoding {
			return NSWorkspace.shared.icon(forFile: path)
		}
		var genericIconPath = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns"
		if type != nil {
			if type == "directory-tile" {
				genericIconPath = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericFolderIcon.icns"
			}else if type == "TrashIcon" || type == "FullTrashIcon" {
				genericIconPath = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/\(type!).icns"
			}
		}
		/// Load image
		let genericIcon = NSImage(contentsOfFile: genericIconPath)
		/// Return icon
		return genericIcon ?? NSImage(size: .zero)
	}
	
	/// Launch app or open file/directory from bundle identifier
	public func launch(bundleIdentifier: String?, completion: (Bool) -> ()) {
		/// Check if bundle identifier is valid
		guard let bundleIdentifier = bundleIdentifier else {
			completion(false)
			return
		}
		var returnable: Bool = false
		/// Check if file path.
		if bundleIdentifier.contains("file://") {
			/// Is path, continue as path.
			let path:        String   = bundleIdentifier
			var isDirectory: ObjCBool = true
			let url:         URL      = URL(string: path)!
			FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
			if isDirectory.boolValue && openFinderInsidePock {
				dockFolderRepository?.popToRootDockFolderController()
				dockFolderRepository?.push(url)
				returnable = true
			}else {
				returnable = NSWorkspace.shared.open(url)
			}
		}else {
			/// Open Finder in Touch Bar
			if bundleIdentifier.lowercased() == Constants.kFinderIdentifier && openFinderInsidePock {
				dockFolderRepository?.popToRootDockFolderController()
				dockFolderRepository?.push(URL(string: NSHomeDirectory())!)
				returnable = true
			}else {
				/// Launch app
				returnable = NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleIdentifier, options: [NSWorkspace.LaunchOptions.default], additionalEventParamDescriptor: nil, launchIdentifier: nil)
			}
		}
		/// Return status
		completion(returnable)
	}
	
	/// TO_IMPROVE: If app is already running, do some special things
	public func launch(item: DockItem?, completion: (Bool) -> ()) {
		guard let _item = item, let identifier = _item.bundleIdentifier else {
			launch(bundleIdentifier: item?.path?.absoluteString, completion: completion)
			return
		}
		let apps = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
		guard _item.bundleIdentifier?.lowercased() != Constants.kFinderIdentifier else {
			launch(bundleIdentifier: _item.bundleIdentifier ?? _item.path?.absoluteString, completion: completion)
			return
		}
		guard apps.count > 0 else {
			launch(bundleIdentifier: _item.bundleIdentifier ?? _item.path?.absoluteString, completion: completion)
			return
		}
		if apps.count > 1 {
			var result = false
			for app in apps {
				result = activate(app: app)
				if result == false { break }
			}
			completion(result)
		}else {
			completion(activate(app: apps.first))
		}
	}
	
	@discardableResult
	private func activate(app: NSRunningApplication?) -> Bool {
		guard let app = app else { return false }
		let _windows = PockDockHelper().getWindowsOfApp(app.processIdentifier) as NSArray?
		
		if let windows = _windows as? [AppExposeItem], activateExpose(with: windows, app: app) {
			return true
		}else {
			if !app.unhide() {
				if !NSWorkspace.shared.launchApplication(withBundleIdentifier: app.bundleIdentifier!, options: .default, additionalEventParamDescriptor: nil, launchIdentifier: nil) {
					return app.activate(options: .activateIgnoringOtherApps)
				}
			}
			return true
		}
	}
	
	private func activateExpose(with windows: [AppExposeItem], app: NSRunningApplication) -> Bool {
		guard windows.count > 0 else {
			return false
		}
		let settings: AppExposeSettings = Preferences[.appExposeSettings]
		guard settings == .always || (settings == .ifNeeded && windows.count > 1) else {
			PockDockHelper().activate(windows.first, in: app)
			return false
		}
		openExpose(with: windows, for: app)
		return true
	}
	
	public func openExpose(with windows: [AppExposeItem], for app: NSRunningApplication) {
		let controller: AppExposeController = AppExposeController.load()
		controller.set(app: app)
		controller.set(elements: windows)
		controller.pushOnMainNavigationController()
	}
	
}
