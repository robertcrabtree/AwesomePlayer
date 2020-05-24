//
//  ConsoleLog.swift
//  AwesomePlayer
//
//  Created by Rob Crabtree on 5/24/20.
//  Copyright © 2020 Certified Organic Software. All rights reserved.
//

import Foundation

public class ConsoleLog: Log {

    private let enabledLevels: LogLevel

    public init(enabledLevels: LogLevel = .allButLow) {
        self.enabledLevels = enabledLevels
    }

    public func low(_ message: String) {
        guard enabledLevels.contains(.low) else { return }
        print("LOW: " + message)
    }

    public func medium(_ message: String) {
        guard enabledLevels.contains(.medium) else { return }
        print("MED: " + message)
    }

    public func high(_ message: String) {
        guard enabledLevels.contains(.high) else { return }
        print("HIGH: " + message)
    }

    public func error(_ message: String) {
        guard enabledLevels.contains(.error) else { return }
        print("ERROR: " + message)
    }
}
