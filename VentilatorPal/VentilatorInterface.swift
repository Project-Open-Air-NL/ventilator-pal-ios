//
//  VentilatorInterface.swift
//  VentilatorPal
//
//  Created by Tijn Kooijmans on 27/03/2020.
//  Copyright © 2020 Sophisti. All rights reserved.
//

//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit
import CoreBluetooth

class VentilatorInterface: NSObject, BLEManagerDelegate {
    
    static var shared = VentilatorInterface()
       
    static let inhaleExhaleRatio = [0: "-", 1: "1:1", 2: "1:1.5", 3: "1:2", 4: "1:3", 5: "1:4"]
    
    public static let DidConnect = "DidConnect"
    public static let IsConnecting = "IsConnecting"
    public static let DidDisconnect = "DidDisconnect"
    public static let SettingsReceived = "SettingsReceived"
    public static let FaultDetected = "FaultDetected"
    public static let DevicesDiscovered = "DevicesDiscovered"
   
    let OP_SET_PARAMS: UInt8 = 1
    let OP_GET_PARAMS: UInt8 = 2
    let OP_START_STOP: UInt8 = 3
    let OP_CALIBRATE_STEPS: UInt8 = 241
    let OP_VREF: UInt8 = 242
    let OP_FAULT: UInt8 = 225
    
    var connectCallback: ((Bool)->())?
    var didConnect = false
    var connectTimer: Timer?
    
    struct Settings {
        
        enum Gender: Int {
            case male = 1
            case female = 2
        }
        
        var patientId: Int
        var tidalVolume: Int
        var inhaleExhaleRatio: Int
        var respiratoryRate: Int
        var height: Int
        var gender: Gender
        var totalTvMl: Int
        var pibWeight: Double
        var running: Bool
        
        init() {
            patientId = 0
            tidalVolume = 6
            inhaleExhaleRatio = 3
            respiratoryRate = 15
            height = 180
            gender = .male
            running = false
            totalTvMl = 0
            pibWeight = 0
            
            updateCalcValues()
        }
        
        mutating func updateCalcValues() {
            if gender == .male {
                pibWeight = (50 + 0.91 * (Double(height) - 152.4));
            } else {
                pibWeight = (45.5 + 0.91 * (Double(height) - 152.4));
            }
            totalTvMl = Int(Double(tidalVolume) * pibWeight);
        }
    }
    
    override init() {
        super.init()
        BLEManager.sharedInstance.delegate = self
    }
    
    public func isConnected() -> Bool {
        return BLEManager.sharedInstance.isConnected()
    }
    
    public func disconnect()
    {
        BLEManager.sharedInstance.disconnect()
    }
    
    public func stopScan() {
        
        BLEManager.sharedInstance.stopScan()
    }
    public func unpairDevice() {
             
        BLEManager.sharedInstance.cachedUUID = nil
        BLEManager.sharedInstance.disconnect()
        BLEManager.sharedInstance.stopScan()
    }
        
    public func discover() {
        unpairDevice()
        BLEManager.sharedInstance.scanPeripherals()
        
    }
    
    public func connect(uuid: String, callback: @escaping (Bool)->()) {
        BLEManager.sharedInstance.cachedUUID = uuid
        BLEManager.sharedInstance.scanPeripherals()
        didConnect = false
        connectCallback = callback

        NotificationCenter.default.post(name: Notification.Name(rawValue: VentilatorInterface.IsConnecting),
                                        object: self,
                                        userInfo: nil)
        
        connectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { (_) in
            self.connectCallback?(false)
        }
    }
    
    public func disconnectWhenDone() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (timer: Timer) in
            if BLEManager.sharedInstance.isConnected() && !BLEManager.sharedInstance.isEmptyQueue {
                //keep checking
            } else {
                BLEManager.sharedInstance.disconnect()
                timer.invalidate()
            }
        }
        
    }
    
    public func getSettings() {
        BLEManager.sharedInstance.writeValue(Data(bytes: [OP_GET_PARAMS]), toCharacteristicWithKey: .write, withResponse: true)
    }
    
    public func writeSettings(_ settings: Settings) {
        if !BLEManager.sharedInstance.isConnected() {
            return
        }
        
        var data = [UInt8](repeating: 0, count: 12)

        data[0] = OP_SET_PARAMS
        data[1] = UInt8(settings.patientId & 0xff)
        data[2] = UInt8((settings.patientId >> 8) & 0xff)
        data[3] = UInt8((settings.patientId >> 16) & 0xff)
        data[4] = UInt8((settings.patientId >> 24) & 0xff)
        data[5] = UInt8(settings.tidalVolume)
        data[6] = UInt8(settings.inhaleExhaleRatio)
        data[7] = UInt8(settings.respiratoryRate)
        data[8] = UInt8(settings.height)
        data[9] = UInt8(settings.gender.rawValue)
        data[10] = UInt8(settings.totalTvMl & 0xff);
        data[11] = UInt8((settings.totalTvMl >> 8) & 0xff);

        BLEManager.sharedInstance.writeValue(Data(bytes: data), toCharacteristicWithKey: .write, withResponse: true)
    }
    
    public func calibrate(steps: Int) {
        var command = [UInt8](repeating: 0, count: 5)

        command[0] = OP_CALIBRATE_STEPS
        command[1] = UInt8(steps & 0xff);
        command[2] = UInt8((steps >> 8) & 0xff);
        command[3] = UInt8((steps >> 16) & 0xff);
        command[4] = UInt8((steps >> 24) & 0xff);
        
        BLEManager.sharedInstance.writeValue(Data(bytes: command), toCharacteristicWithKey: .write, withResponse: true)
    }
    
    public func start() {
        var command = [UInt8](repeating: 0, count: 2)

        command[0] = OP_START_STOP
        command[1] = 1;
        
        BLEManager.sharedInstance.writeValue(Data(bytes: command), toCharacteristicWithKey: .write, withResponse: true)
    }
    
    public func stop() {
        
        var command = [UInt8](repeating: 0, count: 2)

        command[0] = OP_START_STOP
        command[1] = 0;
        
        BLEManager.sharedInstance.writeValue(Data(bytes: command), toCharacteristicWithKey: .write, withResponse: true)
    }
    
    public func setVref(_ vref: UInt8) {
        
        var command = [UInt8](repeating: 0, count: 2)

        command[0] = OP_VREF
        command[1] = vref;
        
        BLEManager.sharedInstance.writeValue(Data(bytes: command), toCharacteristicWithKey: .write, withResponse: true)
    }
    
    func peripheralDidConnect(_ peripheral: CBPeripheral) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: VentilatorInterface.DidConnect),
                                        object: self,
                                        userInfo: nil)
        
        connectCallback?(true)
        connectCallback = nil
        connectTimer?.invalidate()
    }
    func peripheralDidDisconnect(_ peripheral: CBPeripheral) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: VentilatorInterface.DidDisconnect),
                                        object: self,
                                        userInfo: nil)
    }
    
    func peripheralDidUpdateValue(_ value: Data, forCharacteristicWithKey key: BLECharacteristicKey) {
        
        if value.count == 0 {
            print("ParseVentilatorEvent with zero bytes");
            return
        }

        var bytes = [UInt8](repeating: 0, count: value.count)
        (value as NSData).getBytes(&bytes, length: value.count)

        let opcode = bytes[0];

        print("ParseVentilatorEvent opcode \(opcode)");
        switch (opcode) {
        case OP_GET_PARAMS: //Get Settings Response
        
            if bytes.count < 11 {
                print("Invalid get response length");
                return;
            }

            var settings = Settings()
            
            // patient id
            settings.patientId = Int(bytes[1])
            settings.patientId |= Int(bytes[2] << 8)
            settings.patientId |= Int(bytes[3] << 16)
            settings.patientId |= Int(bytes[4] << 24)
            print("ParseVentilatorEvent patient_id \(settings.patientId)");

            // tv ml/kg
            settings.tidalVolume = Int(bytes[5] & 0xff);
            print("ParseVentilatorEvent tv \(settings.tidalVolume)");

            // ie_id: 1->1:1, 2->1:1.5, 3->1:2, 4->1:3, 5->1:4
            settings.inhaleExhaleRatio = Int(bytes[6] & 0xff);
            print("ParseVentilatorEvent ie_id \(settings.inhaleExhaleRatio)");

            // bpm
            settings.respiratoryRate = Int(bytes[7] & 0xff);
            print("ParseVentilatorEvent rr \(settings.respiratoryRate)");

            // cm
            settings.height = Int(bytes[8] & 0xff);
            print("ParseVentilatorEvent height \(settings.height)");

            // gender: 1->male, 2->female
            if let gender = Settings.Gender(rawValue: Int(bytes[9] & 0xff)) {
                settings.gender = gender
            }
            print("ParseVentilatorEvent gender \(settings.gender.rawValue)");

            // running: 1->Ventilator running, 0->Ventilator idle
            settings.running = Bool((bytes[10] & 0xff) == 1);
            print("ParseVentilatorEvent running: \(settings.running)");
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: VentilatorInterface.SettingsReceived),
                                            object: settings,
                                            userInfo: nil)
            break;
        case OP_FAULT: //Fault Indication(0xE1)
        
            // Fault detected in device
            NotificationCenter.default.post(name: Notification.Name(rawValue: VentilatorInterface.FaultDetected),
                                            object: self,
                                            userInfo: nil)
            break
        default:
            break
        }
    }
    func didStartScanning() {
        
    }
    func didDiscoverPeripherals(_ peripherals: [CBPeripheral]) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: VentilatorInterface.DevicesDiscovered),
                                        object: peripherals,
                                        userInfo: nil)
    }
}
