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

import Foundation
import CoreBluetooth
import UIKit

class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    static var sharedInstance = BLEManager()
    static var activeManager: CBCentralManager?
    
    var manager: CBCentralManager!
    
    fileprivate var scannedPeripherals: [CBPeripheral] = []
    fileprivate var rssiValues: [String: Int32] = [:]
    var connectedPeripheral: CBPeripheral?
    var cachedPeripherals: [CBPeripheral]?
    
    fileprivate var characteristics: [BLECharacteristicKey: CBCharacteristic]?
    
    fileprivate var scanTimer:Timer?

    var delegate: BLEManagerDelegate?
    
    fileprivate var isSendingQueue = false
    fileprivate var isWaitingForWriteResponse = false
    
    fileprivate var writeQueue = [(BLECharacteristicKey, Data, Bool)]()
    
    var cachedUUID: String?
    
    var scheduleScan = false
    
    var isEnabled: Bool? {
        switch manager.state {
        case .poweredOn:
            return true
        case .poweredOff:
            return false
        default:
            return nil
        }
    }
    
    var isEmptyQueue: Bool {
        return writeQueue.count == 0 && !isWaitingForWriteResponse
    }
    
    override init(){
        super.init()
        
        manager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    func disconnect() {
        
        scanTimer?.invalidate()
        scanTimer = nil
        
        if let peripheral = connectedPeripheral {
            manager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func resetWriting() {
        isWaitingForWriteResponse = false
    }
    
    fileprivate func writeNextInQueue() {
        
        if writeQueue.isEmpty {
            isSendingQueue = false
            return
        }
        
        if connectedPeripheral != nil {
            if let characteristics = characteristics {
                
                let packet = writeQueue.first!
                writeQueue.removeFirst()
                
                let key = packet.0
                let value = packet.1
                let response = packet.2
                
                if let characteristic = characteristics[key] {
                    
                    var values = [UInt8](repeating: 0, count: value.count)
                    (value as NSData).getBytes(&values, length: value.count)
                    
                    NSLog("Sending \(value.count) bytes of BLE data")
                    
                    isSendingQueue = true
                    isWaitingForWriteResponse = response
                    connectedPeripheral?.writeValue(value, for: characteristic, type: response ? CBCharacteristicWriteType.withResponse : CBCharacteristicWriteType.withoutResponse)
                    
                    if !response {
                        if writeQueue.isEmpty {
                            isSendingQueue = false
                        } else {
                            delay(0.1, closure: {
                                self.writeNextInQueue()
                            })
                        }                        
                    }
                }
            }
        }
    }
    
    func writeValue(_ value: Data, toCharacteristicWithKey key: BLECharacteristicKey, withResponse: Bool) {
        writeQueue.append((key, value, withResponse))
        
        if !isSendingQueue {
            writeNextInQueue()
        }
    }
    
    func connectPeripheral(_ peripheral: CBPeripheral) {
        if let timer = scanTimer {
            timer.invalidate()
            scanTimer = nil
        }
        
        manager.stopScan()
        
        NSLog("Connecting periphiral \(String(describing: peripheral.name))");
        
        peripheral.delegate = self
        
        connectedPeripheral = peripheral;
        
        isWaitingForWriteResponse = false
        
        manager.connect(peripheral, options: nil)
        
    }
    
    func stopScan() {
        scanTimer?.invalidate()
        manager.stopScan()
    }
    
    func scanPeripherals() {
        
        if manager.state != .poweredOn {
            scheduleScan = true
            return
        }

        scheduleScan = false
        
        NSLog("Scanning...")
        
        manager.stopScan()
        
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(BLEManager.scanTimeout), userInfo: nil, repeats: true)
        
        scannedPeripherals.removeAll()
        rssiValues.removeAll()
        
        if !BLEConstants.connectByName {
            manager.scanForPeripherals(withServices: [BLEConstants.advServiceUuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        } else {
            manager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
        
        delegate?.didStartScanning()
    }
    
    @objc func scanTimeout() {
        
        if scannedPeripherals.count > 0 && cachedUUID == nil {
            scannedPeripherals.sort(by: { rssiValues[$0.identifier.uuidString] > rssiValues[$1.identifier.uuidString] })
            
            delegate?.didDiscoverPeripherals(scannedPeripherals)
            
            stopScan()
            
        } else if scannedPeripherals.count == 0 {
            scanPeripherals()
            return
        }
        
    }
    
    func isConnected() -> Bool {
        return connectedPeripheral?.state == CBPeripheralState.connected
    }
    
    // << CBCentralManagerDelegate Protocol Methods
    func centralManagerDidUpdateState(_ central: CBCentralManager){
        NSLog("did update state to \(central.state.rawValue)");
        
        if (central.state == .poweredOn) {
            scanPeripherals()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber){
        
        NSLog("discovered: \(String(describing: peripheral.name)), signal strength: \(RSSI.int32Value)");
        
        if let uuid = cachedUUID {
            if peripheral.identifier.uuidString == uuid {
                connectPeripheral(peripheral)
                stopScan()
                return
            }
        }
        
        //filter duplicates
        if let _ = rssiValues[peripheral.identifier.uuidString] {
            return
        }
        
        rssiValues[peripheral.identifier.uuidString] = RSSI.int32Value
        scannedPeripherals.append(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        NSLog("connected to \(String(describing: peripheral.name))")
        
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        NSLog("disconnected from  \(String(describing: peripheral.name))")
        
        writeQueue.removeAll()
        isSendingQueue = false
        
        self.delegate?.peripheralDidDisconnect(peripheral)
        
        characteristics = nil
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        NSLog("failed to connect  \(String(describing: peripheral.name))")
        
        writeQueue.removeAll()
        isSendingQueue = false
        
        DispatchQueue.main.async(execute: { () -> Void in
            self.delegate?.peripheralDidDisconnect(peripheral)
        })
        
        characteristics = nil
        
        if peripheral.identifier.uuidString == cachedUUID {
            connectPeripheral(peripheral)
        }
    }
    
    // << CBPeripheralDelegate Protocol Methods    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        characteristics = [:]
        
        if let services = peripheral.services {
            for service in services {
                NSLog("discovered service \(service.uuid.uuidString)")
                peripheral.discoverCharacteristics(nil, for: service)
                
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        self.connectedPeripheral?.discoverServices([BLEConstants.dataServiceUuid])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if let chars = service.characteristics {
            for characteristic in chars {
                if let key = BLEConstants.bleCharacteristicKeys[characteristic.uuid.uuidString.lowercased()] {
                    
                    NSLog("discovered characteristic \(characteristic.uuid.uuidString)")
                    
                    characteristics![key] = characteristic
                    
                    if key == .write {
                        writeQueue.removeAll()
                        
                        self.delegate?.peripheralDidConnect(peripheral)                        
                    } 
                
                    if (characteristic.properties.rawValue & CBCharacteristicProperties.indicate.rawValue) != 0 ||
                        (characteristic.properties.rawValue & CBCharacteristicProperties.notify.rawValue) != 0 {
                        //subscribe for indications
                        peripheral.setNotifyValue(true, for: characteristic)
                        
                        NSLog("enabling notifications for characteristic \(key.rawValue)")
                    }
                    
                    if BLEConstants.performInitialRead {
                        if (characteristic.properties.rawValue & CBCharacteristicProperties.read.rawValue) != 0 {
                            //read initial value
                            peripheral.readValue(for: characteristic)
                        }
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
     
        if let key = BLEConstants.bleCharacteristicKeys[characteristic.uuid.uuidString.lowercased()] {
            
            if let value = characteristic.value {
                
                NSLog("Received \(value.count) bytes of BLE data on characteristic \(key.rawValue)")
                
                self.delegate?.peripheralDidUpdateValue(value, forCharacteristicWithKey: key)                
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        isWaitingForWriteResponse = false
        
        NSLog("Response received")
        
        self.writeNextInQueue()
        
    }

}
