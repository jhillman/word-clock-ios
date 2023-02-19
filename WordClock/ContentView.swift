//
//  ContentView.swift
//  WordClock
//
//  Created by Jeff Hillman on 2/13/23.
//

import SwiftUI
import CoreBluetooth
import Flow

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    
    @State private var currentTime = ""
    @State private var ledColor = Color.white
    @State private var birthday = Date()
    @State private var updatingBirthday = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let timeFormatter = DateFormatter()
    private let dateFormatter = DateFormatter()
    private var wordClock = WordClock()
    
    let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let date = Date()
        
        var startComponents = calendar.dateComponents([.day, .month, .year], from: date)
        startComponents.day = 1
        startComponents.month = 1
        
        var endComponents = calendar.dateComponents([.day, .month, .year], from: date)
        endComponents.day = 31
        endComponents.month = 12
        
        return calendar.date(from: startComponents)!...calendar.date(from: endComponents)!
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Word Clock connected:")
                    if wordClock.connected {
                        SwiftUI.Image(systemName: "checkmark.circle.fill")
                    } else {
                        SwiftUI.Image(systemName: "xmark.circle.fill")
                    }
                }
                
                Spacer()
                    .frame(height: 16)
                
                HStack {
                    Text("\(currentTime)")
                        .onReceive(timer) { input in
                            currentTime = timeFormatter.string(from: Date())
                        }
                        .font(Font.system(size: 22))
                    
                    Spacer()
                    
                    Button {
                        wordClock.setTime()
                    } label: {
                        HStack {
                            Text("Set time")
                            SwiftUI.Image(systemName: "clock")
                        }
                        .frame(minWidth: 150, maxWidth: 150)
                        .font(Font.system(size: 18))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                    .disabled(!wordClock.connected)
                }
                
                Spacer()
                    .frame(height: 16)
                
                HStack {
                    ColorPicker("LED color:",
                                selection: $ledColor)
                    .frame(maxWidth: 116)
                    
                    Spacer()
                    
                    Button {
                        wordClock.setLEDColor(color: ledColor)
                    } label: {
                        HStack {
                            Text("Set color")
                            SwiftUI.Image(systemName: "sun.max")
                        }
                        .frame(minWidth: 150, maxWidth: 150)
                        .font(Font.system(size: 18))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                    .disabled(!wordClock.connected)
                }
                
                Spacer()
                    .frame(height: 16)
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Birthdays")
                            .font(Font.system(size: 32))
                        
                        if wordClock.updatingBirthdays {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                    
                    if wordClock.birthdays.isEmpty {
                        Text("no birthdays")
                            .font(Font.system(size: 16))
                    } else {
                        HFlow {
                            ForEach(wordClock.birthdays, id: \.self) { birthday in
                                HStack(spacing: 8) {
                                    Text(dateFormatter.string(from: birthday))
                                        .font(Font.system(size: 14))
                                    Button {
                                        wordClock.removeBirthday(date: birthday)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .tint(Color.gray)
                                    }
                                    .disabled(!wordClock.connected)
                                }
                                .padding(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray, lineWidth: 2)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Spacer()
                        .frame(height: 24)
                    
                    HStack {
                        Button(dateFormatter.string(from: birthday)) {
                            updatingBirthday = true
                        }
                        .foregroundColor(Color.blue)
                        .overlay {
                            DatePicker("",
                                       selection: $birthday,
                                       in: dateRange,
                                       displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .blendMode(.destinationOver)
                        }
                        
                        Spacer()
                        
                        Button {
                            wordClock.addBirthday(date: birthday)
                        } label: {
                            HStack {
                                Text("Add birthday")
                                SwiftUI.Image(systemName: "birthday.cake")
                            }
                            .frame(minWidth: 150, maxWidth: 150)
                            .font(Font.system(size: 18))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue))
                        }
                        .buttonStyle(.plain)
                        .disabled(!wordClock.connected)
                    }
                }
                
                Spacer()
                    .frame(maxHeight: .infinity)
            }
            .padding()
            .onAppear {
                if let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: NSLocale.current) {
                    if dateFormat.contains("a") {
                        timeFormatter.dateFormat = "H:m:ss a"
                    } else {
                        timeFormatter.dateFormat = "HH:mm:ss"
                    }
                }
                
                currentTime = timeFormatter.string(from: Date())
                
                dateFormatter.dateFormat = "MMMM d"
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    wordClock.connect()
                } else {
                    wordClock.disconnect()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
