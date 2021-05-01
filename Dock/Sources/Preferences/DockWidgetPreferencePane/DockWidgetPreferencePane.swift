//
//  DockWidgetPreferencePane.swift
//  Pock
//
//  Created by Pierluigi Galdi on 04/05/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import PockKit

class DockWidgetPreferencePane: NSViewController, PKWidgetPreference {
    
    /// UI
    @IBOutlet weak var notificationBadgeRefreshRatePicker: NSPopUpButton!
    @IBOutlet weak var appExposeSettingsPicker:            NSPopUpButton!
	
	@IBOutlet weak var hideSystemDock: 	  NSButton!
	@IBOutlet weak var disableSystemDock: NSButton!
    
	@IBOutlet weak var hideFinderCheckbox:                 NSButton!
    @IBOutlet weak var showOnlyRunningApps:                NSButton!
	@IBOutlet weak var hideRunningIndicator:			   NSButton!
    @IBOutlet weak var hideTrashCheckbox:                  NSButton!
    @IBOutlet weak var hidePersistentItemsCheckbox:        NSButton!
    @IBOutlet weak var openFinderInsidePockCheckbox:       NSButton!
    @IBOutlet weak var itemSpacingTextField:               NSTextField!

    /// Preferenceable
    static var nibName: NSNib.Name = "DockWidgetPreferencePane"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.superview?.wantsLayer = true
        self.view.wantsLayer = true
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.populatePopUpButtons()
        self.setupCheckboxes()
        self.setupItemSpacingTextField()
    }
    
    private func setupItemSpacingTextField() {
        self.itemSpacingTextField.delegate = self
        self.itemSpacingTextField.placeholderString = "8pt"
    }
    
    private func populatePopUpButtons() {
		let refreshInterval: NotificationBadgeRefreshRateKeys = Preferences[.notificationBadgeRefreshInterval]
        self.notificationBadgeRefreshRatePicker.removeAllItems()
        self.notificationBadgeRefreshRatePicker.addItems(withTitles: NotificationBadgeRefreshRateKeys.allCases.map({ $0.toString() }))
        self.notificationBadgeRefreshRatePicker.selectItem(withTitle: refreshInterval.toString())
		
		let appExposeSetting: AppExposeSettings = Preferences[.appExposeSettings]
        self.appExposeSettingsPicker.removeAllItems()
        self.appExposeSettingsPicker.addItems(withTitles: AppExposeSettings.allCases.map { $0.title })
        self.appExposeSettingsPicker.selectItem(withTitle: appExposeSetting.title)
    }
    
    private func setupCheckboxes() {
		self.hideSystemDock.state				= Preferences[.hideSystemDock]	== true	? .on : .off
        self.hideFinderCheckbox.state           = Preferences[.hideFinder]           	? .on : .off
        self.showOnlyRunningApps.state          = Preferences[.showOnlyRunningApps]  	? .on : .off
		self.hideRunningIndicator.state			= Preferences[.hideRunningIndicator] 	? .on : .off
        self.hideTrashCheckbox.state            = Preferences[.hideTrash]            	? .on : .off
        self.hidePersistentItemsCheckbox.state  = Preferences[.hidePersistentItems]  	? .on : .off
        self.openFinderInsidePockCheckbox.state = Preferences[.openFinderInsidePock] 	? .on : .off
        self.hideTrashCheckbox.isEnabled        = !Preferences[.hidePersistentItems]
		
		let itemSpacing: CGFloat = Preferences[.itemSpacing]
		self.itemSpacingTextField.stringValue = "\(Int(itemSpacing))pt"
		self.updateEnableDisableSystemDockButtonFor(mode: DockHelper.currentMode)
    }

    @IBAction private func didSelectNotificationBadgeRefreshRate(_: NSButton) {
		Preferences[.notificationBadgeRefreshInterval] = NotificationBadgeRefreshRateKeys.allCases[notificationBadgeRefreshRatePicker.indexOfSelectedItem].rawValue
        NSWorkspace.shared.notificationCenter.post(name: .didChangeNotificationBadgeRefreshRate, object: nil)
    }

    @IBAction func didSelectAppExposeSettings(_: NSButton) {
		Preferences[.appExposeSettings] = AppExposeSettings.allCases[appExposeSettingsPicker.indexOfSelectedItem].rawValue
    }
    
	@IBAction private func didChangeHideSystemDockValue(button: NSButton) {
		let shouldHide = button.state == .on
		Preferences[.hideSystemDock] = shouldHide
		DockHelper.setDockMode(shouldHide ? .hidden : .visible)
	}
	
    @IBAction private func didChangeHideFinderValue(button: NSButton) {
		Preferences[.hideFinder] = button.state == .on
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDock, object: nil)
    }
    
    @IBAction private func didChangeShowOnlyRunningAppsValue(button: NSButton) {
		Preferences[.showOnlyRunningApps] = button.state == .on
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDock, object: nil)
    }
	
	@IBAction private func didChangeHideRunningIndicatorValue(button: NSButton) {
		Preferences[.hideRunningIndicator] = button.state == .on
		NSWorkspace.shared.notificationCenter.post(name: .shouldReloadScrubbersLayout, object: nil)
	}
    
    @IBAction private func didChangeHideTrashValue(button: NSButton) {
		Preferences[.hideTrash] = button.state == .on
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDock, object: nil)
    }
    
    @IBAction private func didChangeHidePersistentValue(button: NSButton) {
		Preferences[.hidePersistentItems] = button.state == .on
        hideTrashCheckbox.isEnabled = !Preferences[.hidePersistentItems]
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadPersistentItems, object: nil)
    }
    
    @IBAction private func didChangeOpenFinderInsidePockValue(button: NSButton) {
		Preferences[.openFinderInsidePock] = button.state == .on
    }
	
	@IBAction private func enableOrDisableSystemDock(_ sender: Any?) {
		let previousMode = DockHelper.currentMode
		let newMode: DockMode = {
			guard previousMode == .disabled else {
				return .disabled
			}
			return Preferences[.hideSystemDock] == true ? .hidden : .visible
		}()
		DockHelper.setDockMode(newMode)
		updateEnableDisableSystemDockButtonFor(mode: newMode)
	}
	
	private func updateEnableDisableSystemDockButtonFor(mode: DockMode) {
		hideSystemDock.state 	 = mode == .visible ? .off : .on
		hideSystemDock.isEnabled = mode != .disabled
		disableSystemDock.title = "\(mode == .disabled ? "Enable" : "Disable") System Dock".localized
	}

}

extension DockWidgetPreferencePane: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        let value = itemSpacingTextField.stringValue.replacingOccurrences(of: "pt", with: "")
		Preferences[.itemSpacing] = CGFloat(Int(value) ?? 8)
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadScrubbersLayout, object: nil)
    }
}
