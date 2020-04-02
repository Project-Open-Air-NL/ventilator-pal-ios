//
//  Message.swift
//  VentilatorPal
//
//  Created by Tijn Kooijmans on 27/03/2020.
//  Copyright © 2020 Sophisti. All rights reserved.
//

//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import UIKit
import SwiftMessages

@objc public class Message: NSObject {
    
    @objc public static func success(title: NSString? = nil,
                        message: NSString? = nil) {
        show(title: title as String?,
             message: message as String?,
             theme: .success,
             presentationStyle: .top)
    }
    
    @objc public static func alert(title: NSString? = nil,
                      message: NSString? = nil) {
        show(title: title as String?,
             message: message as String?,
             theme: .error,
             presentationStyle: .top)
    }
    
    @objc public static func warning(title: NSString? = nil,
                        message: NSString? = nil) {
        show(title: title as String?,
             message: message as String?,
             theme: .warning,
             presentationStyle: .top)
    }
    
    @objc public static func info(title: NSString? = nil,
                     message: NSString? = nil) {
        show(title: title as String?,
             message: message as String?,
             theme: .info,
             presentationStyle: .top)
    }
    
    static func show(title: String?,
                     message: String?,
                     theme: Theme,
                     presentationStyle: SwiftMessages.PresentationStyle) {
        // View setup
        let view: MessageView = MessageView.viewFromNib(layout: .centeredView)
        view.configureContent(title: title,
                              body: message,
                              iconImage: nil,
                              iconText: nil,
                              buttonImage: nil,
                              buttonTitle: nil,
                              buttonTapHandler: { _ in SwiftMessages.hide() })
        view.configureTheme(theme, iconStyle: .default)
        view.button?.isHidden = true
        
        let tap = UITapGestureRecognizer(target: view, action: #selector(view.handleTapGesture))
        view.addGestureRecognizer(tap)
        
        // Config setup
        var config = SwiftMessages.defaultConfig
        config.presentationStyle = presentationStyle
//        config.presentationContext = .window(windowLevel: UIWindow.Level.statusBar.rawValue)
        config.duration = .seconds(seconds: 2)
        config.dimMode = .none
        config.shouldAutorotate = true
        config.interactiveHide = true
        
        // Show
        SwiftMessages.show(config: config, view: view)
    }
    
}

extension MessageView {
    
    @objc fileprivate func handleTapGesture(sender: UITapGestureRecognizer) {
        SwiftMessages.hide()
    }
    
}
