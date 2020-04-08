//
//  SettingsViewController.swift
//  VentilatorPal
//
//  Created by Tijn Kooijmans on 08/04/2020.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import DeviceKit

class SettingsViewController: UITableViewController {

    @IBOutlet weak var lblAppVersion: UILabel!
    @IBOutlet weak var lblOsVersion: UILabel!
    @IBOutlet weak var lblDeviceModel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        lblAppVersion.text = "VentilatorPAL v\(versionNumber) (\(buildNumber))"
        lblOsVersion.text = UIDevice.current.systemVersion
        lblDeviceModel.text = Device.current.description
        
    }

}
