//
//  PatientsViewController.swift
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

class PatientsViewController: UITableViewController {

    var patients = [Patient]()
    var selectedPatient: Patient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            try CoreStore.addStorageAndWait()
            
            let lastId = UserDefaults.standard.integer(forKey: "last_patient_selected")
            NSLog("Loading last patient \(lastId)")
            
            if lastId != 0, let patient = try? CoreStore.fetchOne(
                From<Patient>(),
                Where<Patient>("id == %d", lastId) // string format initializer
            ) {
                let vc = UIStoryboard.viewControllerForMainStoryboardWithOfClass(PatientViewController.self) as! PatientViewController
                vc.patient = patient
                navigationController?.pushViewController(vc, animated: false)
                
            }
        }
        catch {
            NSLog("Failed to load data store")
        }
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateData();
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UserDefaults.standard.setValue(0, forKey: "last_patient_selected")
    }
    
    func updateData() {
        do {
           patients = try CoreStore.fetchAll(From<Patient>())
        }
        catch {
           print("Failed to load patients")
        }
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return patients.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "patientCellId", for: indexPath) as! PatientTableViewCell

        let patient = patients[indexPath.section]
        
        cell.lblId.text = "Patient ID: \(patient.id)"
        if let name = patient.deviceName {
            cell.lblDevice.text = "Device: \(name.replacingOccurrences(of: "vntlr-", with: ""))"
        } else {
            cell.lblDevice.text = "Device: -"
        }
        cell.lblTv.text = "TV: \(patient.totalTvMl) ml"
        cell.lblIe.text = "I:E: \(VentilatorInterface.inhaleExhaleRatio[Int(patient.inhaleExhaleRatio)]!)"
        cell.lblRr.text = "RR: \(patient.respiratoryRate) p/m"
        
        cell.btnEdit.actionHandler(controlEvents: .touchUpInside) {
            let vc = UIStoryboard.viewControllerForMainStoryboardWithOfClass(PatientViewController.self) as! PatientViewController
            vc.patient = patient
            self.navigationController?.pushViewController(vc, animated: true)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
