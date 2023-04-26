//
//  AppDelegate.swift
//  ClusterBar
//
//  Created by Robert Biehl on 22.04.23.
//


import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSUserNotificationCenterDelegate  {
    
    
    var statusBarItem: NSStatusItem!
    var menu: NSMenu!
    
    var settingsWindowController: SettingsWindowController?
    
    var slurmController: SlurmController? = nil
    var refreshTimeInterval: TimeInterval = 60 // Adjust this value to change the refresh rate
    
    var refreshTimer: Timer?
    
    var extendedInformation: Bool = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        createSlurmControllerIfNeeded()
        setupStatusBar()
        setupMenu()
        setupTimer()
        setupUserNotificationCenter()
    }
    
    
    func applicationWillTerminate(_ aNotification: Notification) {
        refreshTimer?.invalidate()
    }
    
    func createSlurmControllerIfNeeded() {
        guard let username = Settings.shared.username else {
            return
        }
        let privateKeyURL = Settings.shared.usePrivateKey ? Settings.shared.privateKeyURL : nil
        slurmController = SlurmController(host: Settings.shared.hostname, port: 22, username: username, password: Settings.shared.password, privateKeyURL: privateKeyURL)
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
            self?.refreshData()
        }
    }
    
    private func setupUserNotificationCenter() {
        NSUserNotificationCenter.default.delegate = self
    }
    
    private func updateMenu() {
        menu.removeAllItems()
        
        if let slurmController = slurmController {
            
            // 1. Node information
            let nodePartitions = Dictionary(grouping: slurmController.nodeInfo, by: { $0.partition })
            for (partition, nodes) in nodePartitions {
                let availableNodes = nodes.filter { $0.status == .idle }.count
                let busyNodes = nodes.filter { $0.status == .allocated }.count
                
                let item = NSMenuItem(title: "👥 Partition \(partition): ⏹ \(availableNodes) available, 🟢 \(busyNodes) busy", action: nil, keyEquivalent: "")
                menu.addItem(item)
            }
            
            menu.addItem(.separator())
            
            // 2. Job information
            let jobInfo = extendedInformation ? slurmController.jobInfo : slurmController.jobInfo.filter { $0.user == Settings.shared.username }
            let runningJobs = jobInfo.filter { $0.status == .running }
            let queuedJobs = jobInfo.filter { $0.status == .pending }
            let otherJobs = jobInfo.filter { ($0.status != .running && $0.status != .pending) || $0.status == .failed && $0.age < 86400 }.prefix(5)
            
            
            if runningJobs.count > 0 {
                let item = NSMenuItem(title: "🟢 Running", action: nil, keyEquivalent: "")
                menu.addItem(item)
                for job in runningJobs {
                    var itemTitle = "\(job.id): \(job.name)"
                    itemTitle += " (\(job.ageString))"
                    if extendedInformation {
                        itemTitle += " (User: \(job.user))"
                    }
                    let item = NSMenuItem(title: itemTitle, action: #selector(handleJobClick(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = job
                    item.indentationLevel = 1
                    menu.addItem(item)
                }
            } else {
                let item = NSMenuItem(title: "No running jobs", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            
            if queuedJobs.count > 0 {
                let item = NSMenuItem(title: "⏳ Queued", action: nil, keyEquivalent: "")
                menu.addItem(item)
                for job in queuedJobs {
                    var itemTitle = "\(job.id): \(job.name)"
                    itemTitle += " (\(job.ageString))"
                    if extendedInformation {
                        itemTitle += " (User: \(job.user))"
                    }
                    let item = NSMenuItem(title: itemTitle, action: #selector(handleJobClick(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = job
                    item.indentationLevel = 1
                    menu.addItem(item)
                }
            }
            
            menu.addItem(.separator())
            
            if otherJobs.count > 0 {
                let item = NSMenuItem(title: "📋 Recent", action: nil, keyEquivalent: "")
                menu.addItem(item)
                for job in otherJobs {
                    let emoji: String
                    switch job.status {
                    case .completed:
                        emoji = "✅"
                    case .failed:
                        emoji = "❌"
                    case .cancelled:
                        emoji = "⛔️"
                    default:
                        emoji = "❓"
                    }
                    var itemTitle = "\(emoji) \(job.id): \(job.name)"
                    itemTitle += " (\(job.ageString))"
                    if extendedInformation {
                        itemTitle += " (User: \(job.user))"
                    }
                    let item = NSMenuItem(title: itemTitle, action: #selector(handleRecentJobClick(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = job
                    item.indentationLevel = 1
                    menu.addItem(item)
                }
            } else {
                let item = NSMenuItem(title: "No recent jobs", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            
            
            menu.addItem(.separator())
            
        }
        
        // 3. Refresh action
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsMenuItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(settingsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenuItem)
        
        updateStatusBarIcon()
    }
    
    @objc private func handleJobClick(_ sender: NSMenuItem) {
        guard let job = sender.representedObject as? Job else { return }
        
        let notification = NSUserNotification()
        notification.title = "Job Options"
        notification.informativeText = "Choose an action for job with ID \(job.id)"
        notification.hasActionButton = false
        
        let openStdErrLog = NSUserNotificationAction(identifier: "openStdErrLog", title: "Open stderr log")
        let openStdOutLog = NSUserNotificationAction(identifier: "openStdOutLog", title: "Open stdout log")
        let cancelJob = NSUserNotificationAction(identifier: "cancelJob", title: "Cancel job")
        notification.additionalActions = [openStdErrLog, openStdOutLog, cancelJob]
        
        notification.userInfo = ["jobID": "\(job.id)"]
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc private func handleRecentJobClick(_ sender: NSMenuItem) {
        guard let job = sender.representedObject as? Job else { return }
        
        let notification = NSUserNotification()
        notification.title = "Recent Job Options"
        notification.informativeText = "Choose an action for recent job with ID \(job.id)"
        notification.hasActionButton = false

        let openStdErrLog = NSUserNotificationAction(identifier: "openStdErrLog", title: "Open stderr log")
        let openStdOutLog = NSUserNotificationAction(identifier: "openStdOutLog", title: "Open stdout log")
        notification.additionalActions = [openStdErrLog, openStdOutLog]
        
        notification.userInfo = ["jobID": "\(job.id)", "isRecentJob": true]
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc private func refreshData() {
        createSlurmControllerIfNeeded()
        
        DispatchQueue.global().async { [weak self] in
            self?.slurmController?.refreshData { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.updateMenu()
                        self?.updateStatusBarIcon()
                    case .failure(let error):
                        print("Failed to refresh data: \(error)")
                    }
                }
            }
        }
    }
    
    func updateStatusBarIcon() {
        guard let slurmController = slurmController else {
            statusBarItem.button?.image = NSImage(named: "gray_circle")
            return
        }
        
        statusBarItem.button?.title = "⏳ \(slurmController.jobInfo.filter{$0.status == .pending}) 🏃‍♀️\(slurmController.jobInfo.filter{$0.status == .running})"
        
        let idleNodes = slurmController.nodeInfo.filter { $0.status == .idle }.count
        let totalNodes = slurmController.nodeInfo.count
        let queuedJobs = slurmController.jobInfo.filter { $0.status == .pending }.count
        let myQueuedJobs = slurmController.jobInfo.filter { $0.status == .pending && $0.user == Settings.shared.username}.count
        let myRunningJobs = slurmController.jobInfo.filter { $0.status == .running && $0.user == Settings.shared.username }.count
        
        if myQueuedJobs > 0 || myRunningJobs > 0 {
            statusBarItem.button?.title = "⏳ \(myQueuedJobs) 🏃‍♀️\(myRunningJobs)"
        } else {
            statusBarItem.button?.title = "🤖 Awaiting Jobs"
        }
        
        
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
        slurmController = nil
    }
    
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        extendedInformation = NSEvent.modifierFlags.contains(.option)
        updateMenu()
        refreshData()
    }
    
    // MARK: - NSUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        guard let jobID = notification.userInfo?["jobID"] as? String else { return }
        
        if let response = notification.additionalActivationAction {
            switch response.identifier {
            case "openStdErrLog":
                downloadLogForJob(jobID: jobID, logType: .stderr)
            case "openStdOutLog":
                downloadLogForJob(jobID: jobID, logType: .stdout)
            case "cancelJob":
                slurmController?.cancelSlurmJob(jobID: jobID) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            print("Job \(jobID) has been cancelled")
                        case .failure(let error):
                            print("Failed to cancel job: \(error)")
                        }
                    }
                }
            default:
                break
            }
        }
        
        center.removeDeliveredNotification(notification)
    }
    
    private func downloadLogForJob(jobID: String, logType: SlurmController.LogType) {
        slurmController?.downloadErrorLogForJob(jobID: jobID, logType: logType) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Log for job \(jobID) has been downloaded")
                case .failure(let error):
                    print("Failed to download log: \(error)")
                }
            }
        }
    }
}

