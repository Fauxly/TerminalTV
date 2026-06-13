//
//  SystemInfoProvider.swift
//  TerminalTV
//
//  Created by Fix’s Trick’s on 29.05.2026.
//

import Foundation
import UIKit

final class SystemInfoProvider {

    static let shared = SystemInfoProvider()

    func deviceInfo() -> String {

        let processInfo = ProcessInfo.processInfo

        let uptime = processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        let memory =
            Double(processInfo.physicalMemory) /
            1024 / 1024 / 1024

        return """
==========================
      SYSTEM INFO
==========================

Device      : Apple TV
System      : \(processInfo.operatingSystemVersionString)
RAM         : \(String(format: "%.2f", memory)) GB
Uptime      : \(hours)h \(minutes)m

"""
    }
}
