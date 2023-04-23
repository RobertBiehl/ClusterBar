//
//  SettingsWindowController.swift
//  ClusterBar
//
//  Created by Robert Biehl on 23.04.23.
//

import Cocoa

class SettingsWindowController: NSWindowController {

    init() {
        let settingsViewController = SettingsViewController()
        let window = NSWindow(contentViewController: settingsViewController)
        window.setContentSize(settingsViewController.view.fittingSize)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "Settings"
        
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
