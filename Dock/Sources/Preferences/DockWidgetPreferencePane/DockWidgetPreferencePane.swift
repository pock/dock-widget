//
//  DockWidgetPreferencePane.swift
//  Pock
//
//  Created by Pierluigi Galdi on 04/05/2019.
//  Copyright © 2019 Pierluigi Galdi. All rights reserved.
//

import Foundation
import Defaults
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
        self.notificationBadgeRefreshRatePicker.removeAllItems()
        self.notificationBadgeRefreshRatePicker.addItems(withTitles: NotificationBadgeRefreshRateKeys.allCases.map({ $0.toString() }))
        self.notificationBadgeRefreshRatePicker.selectItem(withTitle: Defaults[.notificationBadgeRefreshInterval].toString())

        self.appExposeSettingsPicker.removeAllItems()
        self.appExposeSettingsPicker.addItems(withTitles: AppExposeSettings.allCases.map { $0.title })
        self.appExposeSettingsPicker.selectItem(withTitle: Defaults[.appExposeSettings].title)
    }
    
    private func setupCheckboxes() {
		self.hideSystemDock.state				= Defaults[.hideSystemDock]	== true	? .on : .off
        self.hideFinderCheckbox.state           = Defaults[.hideFinder]           	? .on : .off
        self.showOnlyRunningApps.state          = Defaults[.showOnlyRunningApps]  	? .on : .off
		self.hideRunningIndicator.state			= Defaults[.hideRunningIndicator] 	? .on : .off
        self.hideTrashCheckbox.state            = Defaults[.hideTrash]            	? .on : .off
        self.hidePersistentItemsCheckbox.state  = Defaults[.hidePersistentItems]  	? .on : .off
        self.openFinderInsidePockCheckbox.state = Defaults[.openFinderInsidePock] 	? .on : .off
        self.hideTrashCheckbox.isEnabled        = !Defaults[.hidePersistentItems]
		self.itemSpacingTextField.stringValue = "\(Defaults[.itemSpacing])pt"
		self.updateEnableDisableSystemDockButtonFor(mode: DockHelper.currentMode)
    }

    @IBAction private func didSelectNotificationBadgeRefreshRate(_: NSButton) {
        Defaults[.notificationBadgeRefreshInterval] = NotificationBadgeRefreshRateKeys.allCases[self.notificationBadgeRefreshRatePicker.indexOfSelectedItem]
        NSWorkspace.shared.notificationCenter.post(name: .didChangeNotificationBadgeRefreshRate, object: nil)
    }

    @IBAction func didSelectAppExposeSettings(_: NSButton) {
        Defaults[.appExposeSettings] = AppExposeSettings.allCases[self.appExposeSettingsPicker.indexOfSelectedItem]
    }
    
	@IBAction private func didChangeHideSystemDockValue(button: NSButton) {
		let shouldHide = button.state == .on
		Defaults[.hideSystemDock] = shouldHide
		DockHelper.setDockMode(shouldHide ? .hidden : .visible)
	}
	
    @IBAction private func didChangeHideFinderValue(button: NSButton) {
        Defaults[.hideFinder] = button.state == .on
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDock, object: nil)
    }
    
    @IBAction private func didChangeShowOnlyRunningAppsValue(button: NSButton) {
        Defaults[.showOnlyRunningApps] = button.state == .on
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDock, object: nil)
    }
	
	@IBAction private func didChangeHideRunningIndicatorValue(button: NSButton) {
		Defaults[.hideRunningIndicator] = button.state == .on
		NSWorkspace.shared.notificationCenter.post(name: .shouldReloadScrubbersLayout, object: nil)
	}
    
    @IBAction private func didChangeHideTrashValue(button: NSButton) {
        Defaults[.hideTrash] = button.state == .on
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDock, object: nil)
    }
    
    @IBAction private func didChangeHidePersistentValue(button: NSButton) {
        Defaults[.hidePersistentItems] = button.state == .on
        hideTrashCheckbox.isEnabled = !Defaults[.hidePersistentItems]
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadPersistentItems, object: nil)
    }
    
    @IBAction private func didChangeOpenFinderInsidePockValue(button: NSButton) {
        Defaults[.openFinderInsidePock] = button.state == .on
    }
	
	@IBAction private func enableOrDisableSystemDock(_ sender: Any?) {
		let previousMode = DockHelper.currentMode
		let newMode: DockMode = {
			guard previousMode == .disabled else {
				return .disabled
			}
			return Defaults[.hideSystemDock] == true ? .hidden : .visible
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
        Defaults[.itemSpacing] = Int(value) ?? 8
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadScrubbersLayout, object: nil)
    }
}
