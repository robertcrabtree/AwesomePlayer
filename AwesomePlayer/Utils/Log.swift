//
//  Log.swift
//  AwesomePlayer
//
//  Created by Rob Crabtree on 5/24/20.
//  Copyright © 2020 Certified Organic Software. All rights reserved.
//

import Foundation

public struct LogLevel: OptionSet {

    public let rawValue: Int

    public static let low = LogLevel(rawValue: 1 << 0)
    public static let medium = LogLevel(rawValue: 1 << 1)
    public static let high = LogLevel(rawValue: 1 << 2)
    public static let error = LogLevel(rawValue: 1 << 3)

    public static let all: LogLevel = [.low, .medium, .high, .error]
    public static let allButLow: LogLevel = [.medium, .high, .error]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public class Log {

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
