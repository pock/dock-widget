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
    @IBOutlet weak var hideFinderCheckbox:                 NSButton!
    @IBOutlet weak var showOnlyRunningApps:                NSButton!
	@IBOutlet weak var hideRunningIndicator:			   NSButton!
    @IBOutlet weak var hideTrashCheckbox:                  NSButton!
    @IBOutlet weak var hidePersistentItemsCheckbox:        NSButton!
    @IBOutlet weak var openFinderInsidePockCheckbox:       NSButton!
	@IBOutlet weak var hasMouseSupport:					   NSButton!
	@IBOutlet weak var showCursor:						   NSButton!
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
        self.hideFinderCheckbox.state           = Defaults[.hideFinder]           ? .on : .off
        self.showOnlyRunningApps.state          = Defaults[.showOnlyRunningApps]  ? .on : .off
		self.hideRunningIndicator.state			= Defaults[.hideRunningIndicator] ? .on : .off
        self.hideTrashCheckbox.state            = Defaults[.hideTrash]            ? .on : .off
        self.hidePersistentItemsCheckbox.state  = Defaults[.hidePersistentItems]  ? .on : .off
        self.openFinderInsidePockCheckbox.state = Defaults[.openFinderInsidePock] ? .on : .off
		self.hasMouseSupport.state 				= Defaults[.hasMouseSupport] 	  ? .on : .off
		self.showCursor.state 					= Defaults[.showCursor] 		  ? .on : .off
        self.hideTrashCheckbox.isEnabled        = !Defaults[.hidePersistentItems]
    }

    @IBAction private func didSelectNotificationBadgeRefreshRate(_: NSButton) {
        Defaults[.notificationBadgeRefreshInterval] = NotificationBadgeRefreshRateKeys.allCases[self.notificationBadgeRefreshRatePicker.indexOfSelectedItem]
        NSWorkspace.shared.notificationCenter.post(name: .didChangeNotificationBadgeRefreshRate, object: nil)
    }

    @IBAction func didSelectAppExposeSettings(_: NSButton) {
        Defaults[.appExposeSettings] = AppExposeSettings.allCases[self.appExposeSettingsPicker.indexOfSelectedItem]
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
		NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDock, 	  object: nil)
		NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDockLayout, object: nil)
	}
    
    @IBAction private func didChangeHideTrashValue(button: NSButton) {
        Defaults[.hideTrash] = button.state == .on
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadPersistentItems, object: nil)
    }
    
    @IBAction private func didChangeHidePersistentValue(button: NSButton) {
        Defaults[.hidePersistentItems] = button.state == .on
        hideTrashCheckbox.isEnabled = !Defaults[.hidePersistentItems]
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadPersistentItems, object: nil)
    }
    
    @IBAction private func didChangeOpenFinderInsidePockValue(button: NSButton) {
        Defaults[.openFinderInsidePock] = button.state == .on
    }
	
	@IBAction private func didChangeHasMouseSupportValue(button: NSButton) {
		Defaults[.hasMouseSupport] = button.state == .on
		showCursor.isEnabled = Defaults[.hasMouseSupport]
		NSWorkspace.shared.notificationCenter.post(name: .shouldReloadScreenEdgeController, object: nil)
	}
	
	@IBAction private func didChangeShowCursorValue(button: NSButton) {
		Defaults[.showCursor] = button.state == .on
	}
}

extension DockWidgetPreferencePane: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        let value = itemSpacingTextField.stringValue.replacingOccurrences(of: "pt", with: "")
        Defaults[.itemSpacing] = Int(value) ?? 8
        NSWorkspace.shared.notificationCenter.post(name: .shouldReloadDockLayout, object: nil)
    }
}
