//
//  PatientViewController.swift
//  VentilatorPal
//
//  Created by Tijn Kooijmans on 27/03/2020.
//  Copyright © 2020 Sophisti. All rights reserved.
//

//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit
import CoreStore
import ActionSheetPicker_3_0
import CoreBluetooth

class PatientViewController: UITableViewController{

    var patient: Patient?
    
    var patientData = VentilatorInterface.Settings()
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var lblId: UILabel!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var lblGender: UILabel!
    @IBOutlet weak var lblHeight: UILabel!
    @IBOutlet weak var lblTV: UILabel!
    @IBOutlet weak var lblIE: UILabel!
    @IBOutlet weak var lblRR: UILabel!
    @IBOutlet weak var lblPIBW: UILabel!
    @IBOutlet weak var lblTVml: UILabel!
    @IBOutlet weak var lblDevice: UILabel!
    @IBOutlet weak var lblVentilator: UILabel!
    
    @IBOutlet weak var sliderHeight: UISlider!
    @IBOutlet weak var sliderTV: UISlider!
    @IBOutlet weak var sliderIE: UISlider!
    @IBOutlet weak var sliderRR: UISlider!
    
    var calibrationSteps: Int?
    var calibrationVref: Int?
    
    var deviceName: String?
    var deviceAddress: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.receiveNotification(_:)),
                                               name: NSNotification.Name(rawValue: VentilatorInterface.DidConnect),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.receiveNotification(_:)),
                                               name: NSNotification.Name(rawValue: VentilatorInterface.IsConnecting),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.receiveNotification(_:)),
                                               name: NSNotification.Name(rawValue: VentilatorInterface.DidDisconnect),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(self.receiveNotification(_:)),
                                              name: NSNotification.Name(rawValue: VentilatorInterface.SettingsReceived),
                                              object: nil)
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(self.receiveNotification(_:)),
                                              name: NSNotification.Name(rawValue: VentilatorInterface.FaultDetected),
                                              object: nil)
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(self.receiveNotification(_:)),
                                              name: NSNotification.Name(rawValue: VentilatorInterface.DevicesDiscovered),
                                              object: nil)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(PatientViewController.handleLongPress))
        tableView.addGestureRecognizer(longPress)
        
        if let patient = patient {
            patientData.patientId = Int(patient.id)
            patientData.tidalVolume = Int(patient.tidalVolume)
            patientData.inhaleExhaleRatio = Int(patient.inhaleExhaleRatio)
            patientData.respiratoryRate = Int(patient.respiratoryRate)
            patientData.height = Int(patient.height)
            if let gender = VentilatorInterface.Settings.Gender(rawValue: Int(patient.gender)) {
                patientData.gender = gender
            }
            
            if patient.deviceAddress == nil {
                discover()
            } else {
                lblStatus.text = ""
                spinner.isHidden = true
            }
            deviceName = patient.deviceName
            deviceAddress = patient.deviceAddress
            
        } else {
            let lastId = UserDefaults.standard.integer(forKey: "last_patient_id")
            patientData.patientId = Int(lastId == 0 ? 101 : lastId + 1)
            
            discover()
        }
        patientData.updateCalcValues()
        
        if let deviceAddress = self.deviceAddress {
            VentilatorInterface.shared.connect(uuid: deviceAddress) { (success: Bool) in
                if (success) {
                    VentilatorInterface.shared.getSettings()
                    VentilatorInterface.shared.disconnectWhenDone()
                }
            }
        }
        
        if #available(iOS 13.0, *) {
            spinner.style = .medium
        } else {
            spinner.style = .gray
        }
        
        UserDefaults.standard.setValue(patientData.patientId, forKey: "last_patient_selected")
       
        updateUI()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        VentilatorInterface.shared.stopScan()
    }
    
    @objc private func receiveNotification (_ notification: Foundation.Notification) {
        if notification.name.rawValue == VentilatorInterface.DidConnect {
            lblStatus.text = "Connected"
            spinner.stopAnimating()
            spinner.isHidden = true
        }
        else if notification.name.rawValue == VentilatorInterface.IsConnecting {
            lblStatus.text = "Connecting"
            spinner.startAnimating()
            spinner.isHidden = false
        } else if notification.name.rawValue == VentilatorInterface.DidDisconnect {
            lblStatus.text = ""
        
        } else if notification.name.rawValue == VentilatorInterface.SettingsReceived {
            let settings = notification.object as! VentilatorInterface.Settings
            patientData.tidalVolume = Int(settings.tidalVolume)
            patientData.inhaleExhaleRatio = Int(settings.inhaleExhaleRatio)
            patientData.respiratoryRate = Int(settings.respiratoryRate)
            updateUI()
        } else if notification.name.rawValue == VentilatorInterface.FaultDetected {
            Message.alert(title: "Fault Detected", message: "VentilatorPal has an issue!")
        } else if notification.name.rawValue == VentilatorInterface.DevicesDiscovered {
            let devices = notification.object as! [CBPeripheral]
            var names = [String]()
            for device in devices {
                if let name = device.name {
                    names.append(name)
                }
            }
            ActionSheetMultipleStringPicker.show(withTitle: "Select device", rows: [
                names
                ], initialSelection: [0], doneBlock: {
                    picker, values, indexes in
                    
                    let device = devices[Int(truncating: values?[0] as! NSNumber)]
                    self.deviceName = device.name
                    self.deviceAddress = device.identifier.uuidString
                    if let deviceName = self.deviceName {
                        self.lblDevice.text = deviceName
                    }
                    if let deviceAddress = self.deviceAddress {
                        VentilatorInterface.shared.connect(uuid: deviceAddress) { (success: Bool) in
                            if (success) {
                                VentilatorInterface.shared.getSettings()
                                VentilatorInterface.shared.disconnectWhenDone()
                            } else {
                                Message.alert(title: "Connection failed", message: "Could not find ventilator")
                            }
                        }
                    }
                    
                    return
                    
            }, cancel: { ActionMultipleStringCancelBlock in

                self.lblStatus.text = ""
                self.spinner.isHidden = true
                
                return
                
            }, origin: self.view)
        }
    }
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        if sender == sliderHeight {
            lblHeight.text = "\(Int(sliderHeight.value))"
            patientData.height = Int(sliderHeight.value)
        } else if sender == sliderTV {
            lblTV.text = "\(Int(sliderTV.value * 2))"
            patientData.tidalVolume = Int(sliderTV.value * 2)
        } else if sender == sliderIE {
            lblIE.text = "\(VentilatorInterface.inhaleExhaleRatio[Int(sliderIE.value)]!)"
            patientData.inhaleExhaleRatio = Int(sliderIE.value)
        } else if sender == sliderRR {
            lblRR.text = "\(Int(sliderRR.value))"
            patientData.respiratoryRate = Int(sliderRR.value)
        }
        patientData.updateCalcValues()
        lblPIBW.text = "\(Int(patientData.pibWeight))"
        lblTVml.text = "\(patientData.totalTvMl)"
    }
    
    @objc func handleLongPress(sender: UILongPressGestureRecognizer){
        if sender.state == .began {
            let touchPoint = sender.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint), indexPath.section == 0, indexPath.row == 1 {
                calibrate()
            }
        }
    }
    
    func calibrate() {
        NSLog("Start calibration")
        
        if let deviceAddress = self.deviceAddress {
            VentilatorInterface.shared.connect(uuid: deviceAddress) { (success: Bool) in
                if (success) {
                    let alert = UIAlertController(title: "Enter calibration steps", message: "", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Apply", style: .default, handler: { (action: UIAlertAction) in
                        if let input = alert.textFields?.first?.text,
                            let steps = Int(input), steps > 0 {
                            
                            VentilatorInterface.shared.calibrate(steps: steps)
                            
                            let alert = UIAlertController(title: "Enter Vref", message: "", preferredStyle: UIAlertController.Style.alert)
                            alert.addAction(UIAlertAction(title: "Apply", style: .default, handler: { (action: UIAlertAction) in
                                if let input = alert.textFields?.first?.text,
                                    let vref = Int(input), vref > 0 && vref <= 255 {

                                    VentilatorInterface.shared.setVref(UInt8(vref))
                                    VentilatorInterface.shared.disconnectWhenDone()
                                    
                                    Message.success(title: "Done", message: "Calibration saved")
                                    
                                } else {
                                    Message.alert(title: "Incorrect value", message: "Enter a number between 0 and 255")
                                    VentilatorInterface.shared.disconnectWhenDone()
                                }
                            }))
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                                textField.placeholder = "0"
                                textField.keyboardType = .decimalPad
                            })
                            self.present(alert, animated: true, completion: nil)
                        } else {
                            Message.alert(title: "Incorrect value", message: "Enter a number higher then 0")
                            VentilatorInterface.shared.disconnectWhenDone()
                        }
                    }))
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    alert.addTextField(configurationHandler: {(textField: UITextField!) in
                        textField.placeholder = "0"
                        textField.keyboardType = .decimalPad
                    })
                    self.present(alert, animated: true, completion: nil)
                } else {
                    Message.alert(title: "Connection failed", message: "Could not find ventilator")
                }
            }
        }
    }
    
    func save() {
        
        if patient == nil {
            
            //new entry
            
            UserDefaults.standard.setValue(patientData.patientId, forKey: "last_patient_id")
            
            CoreStore.perform(
                asynchronous: { (transaction) -> Void in
                    let newPatient = transaction.create(Into<Patient>())
                    newPatient.id = Int32(self.patientData.patientId)
                    newPatient.gender = Int16(self.patientData.gender.rawValue)
                    newPatient.height = Int16(self.patientData.height)
                    newPatient.tidalVolume = Int16(self.patientData.tidalVolume)
                    newPatient.inhaleExhaleRatio = Int16(self.patientData.inhaleExhaleRatio)
                    newPatient.respiratoryRate = Int16(self.patientData.respiratoryRate)
                    newPatient.deviceName = self.deviceName
                    newPatient.deviceAddress = self.deviceAddress
                    self.patient = newPatient
                },
                completion: { _ in
                }
            )
        } else {
            CoreStore.perform(
                asynchronous: { (transaction) -> Void in
                    let editPatient = transaction.edit(self.patient)!
                    editPatient.gender = Int16(self.patientData.gender.rawValue)
                    editPatient.height = Int16(self.patientData.height)
                    editPatient.tidalVolume = Int16(self.patientData.tidalVolume)
                    editPatient.inhaleExhaleRatio = Int16(self.patientData.inhaleExhaleRatio)
                    editPatient.respiratoryRate = Int16(self.patientData.respiratoryRate)
                    editPatient.deviceName = self.deviceName
                    editPatient.deviceAddress = self.deviceAddress
            
                },
                completion: { _ in
                }
            )
        }
     
        if let deviceAddress = self.deviceAddress {
            VentilatorInterface.shared.connect(uuid: deviceAddress) { (success: Bool) in
                if (success) {
                    VentilatorInterface.shared.writeSettings(self.patientData)
                    VentilatorInterface.shared.disconnectWhenDone()

                    Message.success(title: "Done", message: "Settings saved")
                    
                    self.navigationController?.popViewController(animated: true)
                } else {
                    Message.alert(title: "Connection failed", message: "Could not find ventilator")
                }
            }
        }
    }
    
    func discover() {
        VentilatorInterface.shared.discover()
        
        lblStatus.text = "Discovering"
        spinner.startAnimating()
        spinner.isHidden = false
    }
    
    func delete() {
        if let patient = patient {
            CoreStore.perform(
               asynchronous: { (transaction) -> Void in
                    transaction.delete(patient)
               },
               completion: { _ in
                    self.navigationController?.popViewController(animated: true)
               }
           )
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    func updateUI() {
        lblId.text = "Patient ID: \(patientData.patientId)"
        lblGender.text = patientData.gender == .male ? "Male" : "Female"
        lblHeight.text = "\(patientData.height)"
        lblTV.text = "\(patientData.tidalVolume)"
        lblIE.text = "\(VentilatorInterface.inhaleExhaleRatio[patientData.inhaleExhaleRatio]!)"
        lblRR.text = "\(patientData.respiratoryRate)"
        lblPIBW.text = "\(Int(patientData.pibWeight))"
        lblTVml.text = "\(patientData.totalTvMl)"
        sliderHeight.value = Float(patientData.height)
        sliderTV.value = Float(patientData.tidalVolume / 2)
        sliderIE.value = Float(patientData.inhaleExhaleRatio)
        sliderRR.value = Float(patientData.respiratoryRate)

        if let deviceName = deviceName {
            lblDevice.text = deviceName
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let sender = tableView.cellForRow(at: indexPath)
        
        if indexPath.section == 1 && indexPath.row == 0 {
            ActionSheetMultipleStringPicker.show(withTitle: "Choose gender", rows: [
                ["Male", "Female"]
                ], initialSelection: [0], doneBlock: {
                    picker, values, indexes in
                    
                    self.patientData.gender = Int(truncating: values?[0] as! NSNumber) == 0 ? .male : .female
                    self.patientData.updateCalcValues()
                    self.updateUI()
                    
                    return
                    
            }, cancel: { ActionMultipleStringCancelBlock in return }, origin: sender)
        
        } else if indexPath.section == 2 && indexPath.row == 0 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            save()
        } else if indexPath.section == 2 && indexPath.row == 1 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            discover()
        } else if indexPath.section == 2 && indexPath.row == 2 {
            delete()
        }
        
    }
}

