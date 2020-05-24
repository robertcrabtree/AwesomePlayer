//
//  SceneDelegate.swift
//  AwesomePlayer
//
//  Created by Rob Crabtree on 5/24/20.
//  Copyright © 2020 Certified Organic Software. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    let videoURL: URL = Bundle.main.url(forResource: "video", withExtension: "MOV")!

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard (scene as? UIWindowScene) != nil else { return }
        guard let controller = window?.rootViewController as? VideoPlayerViewController else { return }
        controller.videoURL = videoURL
        controller.log = ConsoleLog(enabledLevels: .allButLow)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NotificationCenter.default.post(name: .willResign, object: nil)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}

extension Notification.Name {
    static let willResign: Notification.Name = Notification.Name(rawValue: "willResign")
}
