//
//  DockWidget.swift
//  Dock
//
//  Created by Pierluigi Galdi on 14/05/2020.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import Foundation
import AppKit
import PockKit

class DockWidget: PKWidget {
    
    var identifier: NSTouchBarItem.Identifier = NSTouchBarItem.Identifier(rawValue: "DockWidget")
    var customizationLabel: String = "Dock"
    var view: NSView!
    
    required init() {
        self.view = PKButton(title: "Dock", target: self, action: #selector(printMessage))
    }
    
    @objc private func printMessage() {
        NSLog("[DockWidget]: Hello, World!")
    }
    
}
