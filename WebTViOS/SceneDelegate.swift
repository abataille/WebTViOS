//
//  SceneDelegate.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 27.01.20.
//  Copyright © 2020 Raymund Vorwerk. All rights reserved.
//

import UIKit
import SwiftUI

/// Hosts the root SwiftUI hierarchy inside a UIKit scene.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    
    /// Creates the root window and injects the managed object context.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        // update channellist from userdefaults
       // updateChannels()
      
        // Create the SwiftUI view that provides the window contents.
       // let contentView = ContentView()
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let contentView = ContentView().environment(\.managedObjectContext, context)
       
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.canResizeToFitContent = true
            window.sizeToFit()
          
            //windowScene.sizeRestrictions?.minimumSize = CGSize(width: 180, height: 240)
            // windowScene.sizeRestrictions?.maximumSize = CGSize(width: 180, height: 240)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            // ******** Add code here before root view is shown **********
            window.makeKeyAndVisible()
            // ******** Add code here after root view is shown **********
        }
        
    }
    
    /// Releases scene-specific resources when a scene disconnects.
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        //print("scene disconnect")
    }
    
    /// Resumes work when the scene becomes active.
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        // print("scene active")
    }
    
    /// Pauses transient work when the scene resigns active state.
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        // print("scene inactive")
    }
    
    /// Restores UI state before the scene enters the foreground.
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    /// Gives the app a chance to persist state when entering background.
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        //print("scene background")
     //   (UIApplication.shared.delegate as? AppDelegate)?.saveContext()  
    }
    


}
//extension UIApplication {
//    func addTapGestureRecognizer() {
//        guard let window = windows.first else { return }
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAction))
//        tapGesture.requiresExclusiveTouchType = false
//        tapGesture.cancelsTouchesInView = true
//        tapGesture.delegate = self
//        window.addGestureRecognizer(tapGesture)
//    }
//
//    @objc func tapAction(_ sender: UITapGestureRecognizer) {
//        print("tapped")
////        let view = sender.view
////        let loc = sender.location(in: view)
////        print(loc)
//    }
//}
//
//extension UIApplication: UIGestureRecognizerDelegate {
//    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return true // set to `false` if you don't want to detect tap during other gestures
//    }
//}
