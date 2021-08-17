//
//  Preferences.swift
//  ControlCenter
//
//  Created by Pierluigi Galdi on 18/01/2020.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: self)
    }
    func truncate(length: Int, trailing: String = "…") -> String {
        return self.count > length ? String(self.prefix(length)) + trailing : self
    }
}

extension NSNotification.Name {
    static let didChangeNotificationBadgeRefreshRate = NSNotification.Name("didSelectNotificationBadgeRefreshRate")
    static let shouldReloadDock                      = NSNotification.Name("shouldReloadDock")
    static let shouldReloadScrubbersLayout           = NSNotification.Name("shouldReloadScrubbersLayout")
    static let shouldReloadPersistentItems           = NSNotification.Name("shouldReloadPersistentItems")
    static let shouldReloadScreenEdgeController 	 = NSNotification.Name("shouldReloadScreenEdgeController")
}

enum NotificationBadgeRefreshRateKeys: Double, Codable, CaseIterable {
    case never          = -1
    case instantly      = 0.25
    case oneSecond      = 1
    case fiveSeconds    = 5
    case tenSeconds     = 10
    case thirtySeconds  = 30
    case oneMinute      = 60
    case threeMinutes   = 180
    
    func toString() -> String {
        switch self {
        case .never:
            return "Never".localized
        case .instantly:
            return "Instantly".localized
        case .oneSecond:
            return "1 second".localized
        case .fiveSeconds:
            return "5 seconds".localized
        case .tenSeconds:
            return "10 seconds".localized
        case .thirtySeconds:
            return "30 seconds".localized
        case .oneMinute:
            return "1 minute".localized
        case .threeMinutes:
            return "3 minutes".localized
        }
    }
}

enum AppExposeSettings: String, Codable, CaseIterable {
    case never, ifNeeded, always
    
    var title: String {
        switch self {
        case .never: return "Never".localized
        case .ifNeeded: return "More Than 1 Window".localized
        case .always: return "Always".localized
        }
    }
}

internal struct Preferences {
    internal enum Keys: String {
        case notificationBadgeRefreshInterval
        case appExposeSettings
        case itemSpacing
        case hideSystemDock
        case hideFinder
        case showOnlyRunningApps
        case hideRunningIndicator
        case hideTrash
        case hidePersistentItems
        case openFinderInsidePock
    }
    static subscript<T>(_ key: Keys) -> T {
        get {
            guard let value = UserDefaults.standard.value(forKey: key.rawValue) as? T else {
                if T.self == NotificationBadgeRefreshRateKeys.self, let raw = UserDefaults.standard.value(forKey: key.rawValue) as? Double {
                    return NotificationBadgeRefreshRateKeys(rawValue: raw) as! T
                }
                if T.self == AppExposeSettings.self, let raw = UserDefaults.standard.value(forKey: key.rawValue) as? String {
                    return AppExposeSettings(rawValue: raw) as! T
                }
                switch key {
                case .notificationBadgeRefreshInterval:
                    return NotificationBadgeRefreshRateKeys.tenSeconds as! T
                case .appExposeSettings:
                    return AppExposeSettings.ifNeeded as! T
                case .itemSpacing:
                    return CGFloat(8) as! T
                case .hideSystemDock:
                    return false as! T
                case .hideFinder:
                    return false as! T
                case .showOnlyRunningApps:
                    return false as! T
                case .hideRunningIndicator:
                    return false as! T
                case .hideTrash:
                    return false as! T
                case .hidePersistentItems:
                    return false as! T
                case .openFinderInsidePock:
                    return true as! T
                }
            }
            return value
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: key.rawValue)
        }
    }
    static func reset() {
        Preferences[.notificationBadgeRefreshInterval] = 10
        Preferences[.appExposeSettings] = "ifNeeded"
        Preferences[.itemSpacing] = CGFloat(8)
        Preferences[.hideSystemDock] = false
        Preferences[.hideFinder] = false
        Preferences[.showOnlyRunningApps] = false
        Preferences[.hideRunningIndicator] = false
        Preferences[.hideTrash] = false
        Preferences[.hidePersistentItems] = false
        Preferences[.openFinderInsidePock] = true
    }
}
