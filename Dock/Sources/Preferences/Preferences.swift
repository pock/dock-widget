//
//  Preferences.swift
//  ControlCenter
//
//  Created by Pierluigi Galdi on 18/01/2020.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Defaults

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

enum AppExposeSettings : String, Codable, CaseIterable {
    case never, ifNeeded, always

    var title: String {
        switch self {
        case .never: return "Never".localized
        case .ifNeeded: return "More Than 1 Window".localized
        case .always: return "Always".localized
        }
    }
}

extension Defaults.Keys {
    static let notificationBadgeRefreshInterval = Defaults.Key<NotificationBadgeRefreshRateKeys>("notificationBadgeRefreshInterval", default: .tenSeconds)
    static let appExposeSettings                = Defaults.Key<AppExposeSettings>("appExposeSettings", default: .ifNeeded)
    static let itemSpacing                      = Defaults.Key<Int>("itemSpacing",             default: 8)
    static let hideFinder                       = Defaults.Key<Bool>("hideFinder",             default: false)
    static let showOnlyRunningApps              = Defaults.Key<Bool>("showOnlyRunningApps",    default: false)
	static let hideRunningIndicator				= Defaults.Key<Bool>("hideRunningIndicator",   default: false)
    static let hideTrash                        = Defaults.Key<Bool>("hideTrash",              default: false)
    static let hidePersistentItems              = Defaults.Key<Bool>("hidePersistentItems",    default: false)
    static let openFinderInsidePock             = Defaults.Key<Bool>("openFinderInsidePock",   default: true)
	static let hasMouseSupport					= Defaults.Key<Bool>("hasMouseSupport",		   default: true)
	static let showCursor					 	= Defaults.Key<Bool>("showCursor",		   	   default: true)
}
