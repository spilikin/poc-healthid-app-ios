// AcmeAuth/SceneDelegate.swift
// 


import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appState = AppState()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
                
        if let userActivity = connectionOptions.userActivities.first,
userActivity.activityType == NSUserActivityTypeBrowsingWeb,
                let url = userActivity.webpageURL  {
            appState.onOpenURL(url)
        }
        
        let homeView = HomeView().environmentObject(appState)

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: homeView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL else {
          return
        }
        appState.onOpenURL(url)
    }

}

