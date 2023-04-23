//
//  SSHManager.swift
//  ClusterBar
//
//  Created by Robert Biehl on 22.04.23.
//


import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    
    var statusBarItem: NSStatusItem!
    var menu: NSMenu!
    
    var settingsWindowController: SettingsWindowController?
    
    let slurmController = SlurmController(host: "your_host", port: 22, username: "your_username", password: "your_password")
    let refreshTimeInterval: TimeInterval = 60 // Adjust this value to change the refresh rate
    
    var refreshTimer: Timer?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        setupMenu()
        setupTimer()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        refreshTimer?.invalidate()
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.button?.title = "Slurm"
    }
    
    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self
        statusBarItem.menu = menu
        updateMenu()
    }
    
    private func setupTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshTimeInterval, repeats: true) { [weak self] _ in
            self?.updateMenu()
        }
    }
    
    private func updateMenu() {
        menu.removeAllItems()
        
        // 1. Node information
        let nodeGroups = Dictionary(grouping: slurmController.nodeInfo, by: { $0.group })
        for (group, nodes) in nodeGroups {
            let availableNodes = nodes.filter { $0.status == "idle" }.count
            let busyNodes = nodes.filter { $0.status == "allocated" }.count
            
            let item = NSMenuItem(title: "👥 Group \(group): ⏹ \(availableNodes) available, 🟢 \(busyNodes) busy", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
        
        // 2. Job information
        let userJobInfo = slurmController.jobInfo.filter { $0.user == "rbiehl" }
        let runningJobs = userJobInfo.filter { $0.status == "RUNNING" }
        let queuedJobs = userJobInfo.filter { $0.status == "PENDING" }
        let otherJobs = userJobInfo.filter { $0.status != "RUNNING" && $0.status != "PENDING" && $0.age < 86400 }.sorted { $0.age > $1.age }.prefix(5)
        
        for job in runningJobs {
            let item = NSMenuItem(title: "🟢 Running Job: \(job.name) (\(job.id))", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        
        for job in queuedJobs {
            let item = NSMenuItem(title: "⏳ Queued Job: \(job.name) (\(job.id))", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
        
        for job in otherJobs {
            let item = NSMenuItem(title: "📋 Recent Job: \(job.name) (\(job.id)) - \(job.status)", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
        
        // 3. Refresh action
        let refreshItem = NSMenuItem(title: "🔄 Refresh", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsMenuItem = NSMenuItem(title: "⚙️ Settings", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(settingsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(title: "❌ Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)
        
        updateStatusBarIcon()
    }
    
    @objc private func refreshData() {
        slurmController.refreshData { [weak self] result in
            switch result {
            case .success:
                self?.updateMenu()
            case .failure(let error):
                print("Failed to refresh data: \(error)")
            }
        }
    }
    
    func updateStatusBarIcon() {
//        guard let slurmController = slurmController else {
//            statusBarItem.button?.image = NSImage(named: "gray_circle")
//            return
//        }
        
        let idleNodes = slurmController.nodeInfo.filter { $0.status == "idle" }.count
        let totalNodes = slurmController.nodeInfo.count
        let queuedJobs = slurmController.jobInfo.filter { $0.status == "PENDING" }.count
        
        if idleNodes == totalNodes {
            statusBarItem.button?.image = NSImage(named: "green_circle")
        } else if queuedJobs > 0 || idleNodes == 0 {
            statusBarItem.button?.image = NSImage(named: "red_circle")
        } else {
            statusBarItem.button?.image = NSImage(named: "orange_circle")
        }
    }
    
    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        refreshData()
    }
}

