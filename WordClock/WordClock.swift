//
//  WordClock.swift
//  WordClock
//
//  Created by Jeff Hillman on 2/13/23.
//

import Foundation
import CoreBluetooth
import SwiftUI

final class WordClock: NSObject, ObservableObject {
    @Published var connected = false
    @Published var updatingBirthdays = false
    @Published var birthdays: [Date] = []
    
    private let wordClockServiceUUID = "FFE0"
    private let wordClockCharacteristicUUID = "FFE1"
    private let wordClockUUID = "ACD54B4B-E4A5-739D-37DB-F7D6313547D0"

    private var centralManager: CBCentralManager?
    private var wordClock: CBPeripheral?
    private var wordClockCharacteristic: CBCharacteristic?
    private var color: Color?
    private var birthday: Date?
    
    func connect() {
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func disconnect() {
        if let wordClock = wordClock {
            centralManager?.cancelPeripheralConnection(wordClock)
        }
        
        wordClock = nil
        connected = false
    }
    
    func setTime() {
        if let setTimeData = "settime\n".data(using: .ascii), let characteristic = wordClockCharacteristic {
            wordClock?.writeValue(setTimeData, for: characteristic, type: .withoutResponse)
        }
    }
    
    func setLEDColor(color: Color) {
        if let setTimeData = "setcolor\n".data(using: .ascii), let characteristic = wordClockCharacteristic {
            self.color = color
            wordClock?.writeValue(setTimeData, for: characteristic, type: .withoutResponse)
        }
    }
    
    func listBirthdays() {
        updatingBirthdays = true
        
        if let listBirthdaysData = "listbdays\n".data(using: .ascii), let characteristic = wordClockCharacteristic {
            wordClock?.writeValue(listBirthdaysData, for: characteristic, type: .withoutResponse)
        }
    }
    
    func addBirthday(date: Date) {
        updatingBirthdays = true
        
        if let addBirthdayData = "addbday\n".data(using: .ascii), let characteristic = wordClockCharacteristic {
            self.birthday = date
            wordClock?.writeValue(addBirthdayData, for: characteristic, type: .withoutResponse)
        }
    }
    
    func removeBirthday(date: Date) {
        updatingBirthdays = true
        
        if let removeBirthdayData = "removebday\n".data(using: .ascii), let characteristic = wordClockCharacteristic {
            self.birthday = date
            wordClock?.writeValue(removeBirthdayData, for: characteristic, type: .withoutResponse)
        }
    }
}

extension WordClock: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [CBUUID(string: wordClockServiceUUID)])
        } else {
            wordClock = nil
            connected = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "WordClock", peripheral.identifier.uuidString == wordClockUUID {
            central.stopScan()
            peripheral.delegate = self
            central.connect(peripheral)

            wordClock = peripheral
            connected = true
        }
    }
}

extension WordClock: CBPeripheralDelegate {
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        wordClock?.discoverServices([CBUUID(string: wordClockServiceUUID)])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        wordClock = nil
        connected = false
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid.uuidString == wordClockCharacteristicUUID  {
                wordClockCharacteristic = characteristic

                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
                
                listBirthdays()
                
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard
            characteristic == wordClockCharacteristic,
            let characteristicValue = characteristic.value,
            let characteristicString = String(data: characteristicValue, encoding: .utf8)
        else { return }
        
        let birthdayCountRegex = /Birthday count: (?<count>\d+)/
        let birthdayRegex = /Birthday (?<number>\d+)\/(?<count>\d+): (?<month>\d+)\/(?<day>\d+)/
        
        if characteristicString.starts(with: "Set the date & time") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/M/d,HH:mm:ss\n"
                let time = dateFormatter.string(from: Date())
                
                if let timeData = time.data(using: .ascii) {
                    self.wordClock?.writeValue(timeData, for: characteristic, type: .withoutResponse)
                }
            }
        } else if characteristicString.starts(with: "Set the color"), let color = color {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            let ledColor = String(format: "#%02x%02x%02x\n", Int(red * 255), Int(green * 255), Int(blue * 255))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let ledColorData = ledColor.data(using: .ascii) {
                    self.wordClock?.writeValue(ledColorData, for: characteristic, type: .withoutResponse)
                }
            }
        } else if characteristicString.starts(with: "Enter birthday"), let birthday = birthday {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M/d\n"
                let date = dateFormatter.string(from: birthday)
                
                if let birthdayData = date.data(using: .ascii) {
                    self.wordClock?.writeValue(birthdayData, for: characteristic, type: .withoutResponse)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.listBirthdays()
                    }
                }
            }
        } else if let birthdayCountMatch = characteristicString.firstMatch(of: birthdayCountRegex),
                  let count = Int(birthdayCountMatch.count) {
            if count == 0 {
                DispatchQueue.main.async {
                    self.updatingBirthdays = false
                }
            }
        } else if let birthdayMatch = characteristicString.firstMatch(of: birthdayRegex),
                  let number = Int(birthdayMatch.number), let count = Int(birthdayMatch.count),
                  let month = Int(birthdayMatch.month), let day = Int(birthdayMatch.day),
                  let birthday = Calendar(identifier: .gregorian).date(from: DateComponents(month: month, day: day)) {
            DispatchQueue.main.async {
                if number == 1 {
                    self.birthdays.removeAll()
                }
                
                self.birthdays.append(birthday)
                
                if number == count {
                    self.birthdays.sort()
                    self.updatingBirthdays = false
                }
            }
        }
    }
}
