//
//  ViewController.swift
//  BLE_Demo
//
//  Created by Konstruktion on 30.07.18.
//  Copyright © 2018 EMKA Beschlagteile. All rights reserved.
//

import UIKit
import SwiftSocket

class LoginViewController: UIViewController, SchlosslistDelegate {
    
    var socketClient: TCPClient?
    var benutzer = appBenutzer()
    
    var rightLogin = false
    
    @IBOutlet weak var benutzername: UITextField!
    @IBOutlet weak var passwort: UITextField!
    
    @IBAction func LoginTapped(_ sender: Any) {
        let Benutzername: String! = benutzername!.text
        let Passwort: String! = passwort!.text
        self.benutzer.Benutzername = Benutzername
        
        processClientSocket(Benutzername: Benutzername!, Passwort: Passwort!)
        
        self.navigationController?.performSegue(withIdentifier: "showList", sender: nil)
    }
    
    //transmit the benutzer data to the second page
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "showList" else {
            return
        }
        
        let nc = segue.destination as! UINavigationController
        let nfc = nc.childViewControllers.first as! SchlosslistViewController
        nfc.thisBenutzer = benutzer
        nfc.delegate = self
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return rightLogin
    }
    
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func processClientSocket(Benutzername b: String!, Passwort p: String!){
        socketClient = TCPClient(address: "*.*.*.*", port: 1983)
        // connect to the scoket with IP Address *.*.*.* and port number 1983

        switch self.socketClient!.connect(timeout: 1) {
        case .success:
           /* DispatchQueue.main.async {
                self.alert(msg: "connect success", after: {})
            }*/
            
            let msgtosend0 = "0,\(b!),\(p!)#"
            _ = self.socketClient!.send(string: msgtosend0)
            print(msgtosend0)
            // send Benutzername und Passwort to Webserver
                
                
            while self.benutzer.schlossList.count != self.benutzer.schlossAnzahl {
                if let receiveData = self.socketClient!.read(1024 * 10) {
                    self.processList(withData: receiveData)
                }
                
                self.benutzer.printBenutzer()
            }
            
            self.rightLogin = true
            
            
     
        case .failure(let error):
            DispatchQueue.main.async {
                self.alert(msg: error.localizedDescription, after: {})
            }
        }
        
    }
    
    
    // MARK: Process Incoming Message
    func processList(withData raData: [Byte]) {
        // process the comming message
        
        var msg: String = ""
        for s in raData {
            msg += String(UnicodeScalar(s))
        }
        print(msg)
        
        switch raData[0] {
        case 48:
            // CMD_LOGIN
            self.anmelden(data: raData)
            
        case 49:
            //CMD_GET_NUMBER_OF_LATCHES
            self.anzahlFragen(data: raData)
            
        case 50:
            //CMD_GET_INFO_LATCH
            self.infoFragen(data: raData)
            
        default:
            self.alert(msg: "Falsch Data", after: {})
        }
        
    }
    
    func anmelden(data aData: [Byte]) {
        if aData[2] == 48 {
            rightLogin = true
            _ = self.socketClient!.send(string: "1#")
        } else {
            self.rightLogin = false
            self.alert(msg: "Benutzername oder Passwort falsch!", after: {})
        }
    }
    
    func anzahlFragen(data aData: [Byte]) {
        var anzahl : Int = 0
        if aData[3] == 35 {
            anzahl = Int(aData[2]) - 48
            print("\(anzahl)")
        } else if aData[4] == 35 {
            anzahl = (Int(aData[2]) - 48) * 10 + Int(aData[3]) - 48
        } else if aData[5] == 35 {
            anzahl = (Int(aData[2]) - 48) * 100 + (Int(aData[3]) - 48) * 10 + Int(aData[4]) - 48
        } else {
            self.alert(msg: "Falsch!", after:{})
        }
        
        self.benutzer.schlossAnzahl = anzahl
        print("\(self.benutzer.schlossAnzahl)")
        
        for n in 0...(anzahl - 1) {
            _ = self.socketClient?.send(string: "2,\(n)#")
            while true {
                if let receiveData = self.socketClient!.read(1024 * 10) {
                    
                    var msg: String = ""
                    for s in receiveData {
                        msg += String(UnicodeScalar(s))
                    }
                    print(msg)
                    
                    infoFragen(data: receiveData)
                    
                    break
                    // after process a information break this while-loop and continue next for-loop
                }
            }
        }
    }
    
    func infoFragen(data aData: [Byte]){
        // get Index in the received Information
        var aIndex: String = ""
        var cot = 2
        while aData[cot] != 44 {
            cot += 1
        }
        for l in 2...(cot - 1) {
            aIndex += String(UnicodeScalar(aData[l]))
        }
        
        // get serial Nummer in the received Information
        var aSerialNummer: String = ""
        var cof = cot + 1
        while aData[cof] != 44 {
            cof += 1
        }
        for n in (cot + 1)...(cof - 1) {
            aSerialNummer += String(UnicodeScalar(aData[n]))
        }
        
        // get Name in the received Information
        var aName: String = ""
        var cou = cof + 1
        while aData[cou] != 44 {
            cou += 1
        }
        for m in (cof + 1)...(cou - 1) {
            aName += String(UnicodeScalar(aData[m]))
        }
        
        // get Beschreibung in the received Infromation
        var aBeschreibung: String = ""
        var con = cou + 1
        while aData[con] != 35 {
            con += 1
        }
        for o in (cou+1)...(con - 1) {
            aBeschreibung += String(UnicodeScalar(aData[o]))
        }
        
        // add this schloss to the Benutzer Object
        self.benutzer.addSchloss(withIndex: aIndex, andSerialNummer: aSerialNummer, andName: aName, andBeschreibung: aBeschreibung)
        self.benutzer.printSchloss()
        
    }
    
    func alert(msg:String, after:()->(Void)) {
        let alertController = UIAlertController(title: "", message: msg, preferredStyle: .alert)
        self.present(alertController, animated: true, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
            alertController.dismiss(animated: false, completion: nil)
        }
    }
    
    // MARK: - SchlosslistDelegate
    func abmelden() {
        _ = self.socketClient?.close()
    }
    
}

