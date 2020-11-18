//
//  SystemSoundHelper.swift
//  Dock
//
//  Created by Pierluigi Galdi on 17/11/20.
//  Copyright © 2020 Pierluigi Galdi. All rights reserved.
//

import AVKit

public class SystemSound {
	
	/// Name
	public struct Name {
		fileprivate let filepath: String
		/// Defaults
		public static let volume_mount  = Name(filepath: "system/Volume Mount.aif")
		public static let move_to_trash = Name(filepath: "finder/move to trash.aif")
	}
	
	/// Play given sound
	public static func play(_ systemSoundName: Name) {
		let url = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/\(systemSoundName.filepath)")
		var soundID: SystemSoundID = 0
		AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
		AudioServicesPlaySystemSound(soundID)
	}
	
}
