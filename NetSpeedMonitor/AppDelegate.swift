//
//  AppDelegate.swift
//  NetSpeedMonitor
//
//  Created by Huang Kai on 2019/3/10.
//  Copyright © 2019 Team Elegracer. All rights reserved.
//

import Cocoa
import ServiceManagement
import SystemConfiguration
import CoreGraphics

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var menu: NSMenu!
    @IBOutlet var startAtLoginButton: NSMenuItem!
    @IBAction func toggleStartAtLoginButton(_ sender: NSMenuItem) {
        let launcherAppId = "elegracer.NetSpeedMonitorHelper"
//        print(sender.state, NSButton.StateValue.on)
        if sender.state == .off {
            if !SMLoginItemSetEnabled(launcherAppId as CFString, true) {
                print("The login item was not successfull")
            } else {
                UserDefaults.standard.set(true, forKey: "isStartAtLogin")
                sender.state = .on
            }
        } else {
            if !SMLoginItemSetEnabled(launcherAppId as CFString, false) {
                print("The login item was not successfull")
            } else {
                UserDefaults.standard.set(false, forKey: "isStartAtLogin")
                sender.state = .off
            }
        }
    }
    @IBOutlet var quitButton: NSMenuItem!
    @IBAction func pressQuitButton(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(sender)
    }

    var uploadSpeed: Double = 0.0
    var downloadSpeed: Double = 0.0
    var uploadMetric: String = "KB"
    var downloadMetric: String = "KB"
    var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    var netStat: NetSpeedStat!
    var timer: Timer!

    var statusBarTextAttributes : [NSAttributedString.Key : Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right                  // default is .right
        paragraphStyle.maximumLineHeight = 11               // default is 10
        var map = [NSAttributedString.Key : Any]()

        if let font = NSFont(name: "SFMono-Regular", size: 11) {
            // Custom
            paragraphStyle.paragraphSpacing = -5
            map[NSAttributedString.Key.font] = font
            if #available(macOS 11, *) {
                // negative value make the bottom goes down
                map[NSAttributedString.Key.baselineOffset] = -6
            }
        } else {
            paragraphStyle.paragraphSpacing = -7
            map[NSAttributedString.Key.font] = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        }
        map[NSAttributedString.Key.paragraphStyle] = paragraphStyle
        return map
    }

    func updateSpeed() {
        if let button = statusItem.button {
            button.attributedTitle = NSAttributedString(string: "\n\(String(format: "%5.1lf", uploadSpeed)) \(uploadMetric)/s ↑\n\(String(format: "%5.1lf", downloadSpeed)) \(downloadMetric)/s ↓", attributes: statusBarTextAttributes)
            var buttonSize = button.attributedTitle.size()
            buttonSize.width = ceil(buttonSize.width)
            buttonSize.height = ceil(buttonSize.height)
            button.frame.size = buttonSize
            statusItem.length = buttonSize.width
            button.superview?.superview?.constraints.forEach({ constraint in
                if (constraint.constant == 16) {
                    constraint.constant = 0
                }
            })
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let launcherAppId = "elegracer.NetSpeedMonitorHelper"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty

        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
        self.updateSpeed()

        startAtLoginButton.state = UserDefaults.standard.bool(forKey: "isStartAtLogin") ? .on : .off

        statusItem.menu = menu

        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if (self.netStat == nil) {
                self.netStat = NetSpeedStat()
//                print(String(format: "netStat: %p", self.netStat))
                self.downloadSpeed = 0.0
                self.downloadMetric = "KB"
                self.uploadSpeed = 0.0
                self.uploadMetric = "KB"
            } else {
                if let statResult = self.netStat.getStatsForInterval(1.0) as NSDictionary? {
                    let total = statResult.allValues.reduce((UInt64(0), UInt64(0))) { partialResult, dict in
                        let list = dict as! Dictionary<String, UInt64>
                        return (partialResult.0 + UInt64(list["deltain"] ?? 0), partialResult.1 + UInt64(list["deltaout"] ?? 0))
                    }
                    let deltain: Double = Double(total.0) / 1024.0
                    let deltaout: Double = Double(total.1) / 1024.0
                    if (deltain > 1000.0) {
                        self.downloadSpeed = deltain / 1024.0
                        self.downloadMetric = "MB"
                    } else {
                        self.downloadSpeed = deltain
                        self.downloadMetric = "KB"
                    }
                    if (deltaout > 1000.0) {
                        self.uploadSpeed = deltaout / 1024.0
                        self.uploadMetric = "MB"
                    } else {
                        self.uploadSpeed = deltaout
                        self.uploadMetric = "KB"
                    }
                    self.updateSpeed()
                    //                        print("deltaIn: \(self.downloadSpeed) \(self.downloadMetric)/s, deltaOut: \(self.uploadSpeed) \(self.uploadMetric)/s")
                }
            }
        }
        RunLoop.current.add(self.timer, forMode: .common)
    }
}
