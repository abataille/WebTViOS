//
//  channels.swift
//  WebTV
//
//  Created by Raymund Vorwerk on 18.10.19.
//  Copyright © 2019 Raymund Vorwerk. All rights reserved.

import SwiftUI
import Foundation
import CoreData

// The default channel list used for reset
public var defaultChannelList:[String:[String]] = [
    "Apple BipBop Demo": [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
        "",
        "1",
    ],
    "Mux Test Stream": [
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        "",
        "1",
    ],
    "Sintel Demo": [
        "https://test-streams.mux.dev/pts_shift/master.m3u8",
        "",
        "1",
    ],
]


public var channelList = [String:[String]]()

/// Legacy channel management form backed by Core Data.
struct ChannelView: View {
    // for CoreData
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Channel.name, ascending: true)],
        animation: .default)
    private var entities: FetchedResults<Channel>
    
    @Binding var keys: [String] // = Array(channelList.keys).sorted()
    @State var isEditMode: EditMode = .active
    @State var sender: String
    @State var senderName: String
    @State var preview: Bool
    
    
    @State private var status = true
    @State private var showingAlert = false
    @State private var showingAlert1 = false
    var dismiss: () -> ()
    
    /// Renders the add, edit, and delete channel form.
    var body: some View {
        VStack() {
            HStack {
                Spacer()
                Button(action: {
                    self.dismiss()
                }) {  Image(systemName: "xmark.circle")
                        .resizable()
                        .frame(width: 20.0, height: 20.0)
                }.buttonStyle(NoOutlineButton())
            }.padding(.trailing, 15)
            
            Form {
                
                Section(header: Text(String(localized: "Add Channels"))) {
                    
                    TextField(String(localized: "Enter name of Station"), text: $senderName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField(String(localized: "Enter Station URL"), text: $sender)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle(isOn: $preview) {
                        Text(String(localized: "Live Preview"))
                    }
                    
                    Button(action: {
                        self.storeNewChannelInDatabase(senderName: senderName, url: sender, preview: preview)
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.body)
                            Text(String(localized: "Save"))
                        }
                    }
                    .buttonStyle(OutlineButton1())
                }
                
                Section(header: Text(String(localized: "Edit / Remove Channels"))) {
                    List {
                        ForEach(entities) { channel in
                            Text("\(channel.name!)")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    self.senderName = channel.name ?? ""
                                    self.sender = channel.url?.absoluteString ?? ""
                                    self.preview = channel.preview
                                }
                        }.onDelete(perform: deleteFromDatabase)
                    }
                }
                
                Section() {
                    HStack() {
                        Button(action: {
                            self.showingAlert = true
                        }) {
                            Text(String(localized: "Reset"))
                        }.buttonStyle(OutlineButton2())
                            .alert(isPresented: $showingAlert) {
                                Alert(
                                    title: Text(String(localized: "Are you sure?")),
                                    message: Text(String(localized: "Should the channels be reset to default?")),
                                    primaryButton: .cancel(Text(String(localized: "No"))),
                                    secondaryButton: .destructive(Text(String(localized: "Yes")), action: {self.resetChannelsToDefault()})
                                )
                            }.padding(.leading, 5)
                        Spacer()
                        Button(action: {
                            self.showingAlert1 = true
                        }) {
                            Text(String(localized: "Refresh"))
                        }.buttonStyle(OutlineButton2())
                            .alert(isPresented: $showingAlert1) {
                                Alert(
                                    title: Text(String(localized: "Are you sure?")),
                                    message: Text(String(localized: "Should the channels be updated?")),
                                    primaryButton: .cancel(Text(String(localized: "No"))),
                                    secondaryButton: .destructive(Text(String(localized: "Yes")), action: {self.refreshChannelsFromWeb()})
                                )
                            }.padding(.leading, 5)
                    }
                }
            }.environment(\.editMode, self.$isEditMode)
        }
    }
    
    /// Returns whether the current form content is usable.
    private func checkContent() -> Bool {
        // returns true if the button should diabled
        return senderName.isEmpty || sender.isEmpty ? false : true
    }
    
    /// Inserts or updates a channel in Core Data and the in-memory list.
    private func storeNewChannelInDatabase(senderName: String, url: String, preview: Bool) {
        // 1. do a replace, if name exists, otherwise add the new record
        //    query database
        guard let found = entities.filter({$0.name == senderName}).first else {
            let ch = Channel(context: viewContext)
            ch.name = senderName
            ch.url = URL(string: url)
            ch.epg = ""
            ch.preview = preview
            ch.timestamp = Date()
            do {
                try viewContext.save()
            } catch {
                print(error)
            }
            return
        }
        
        viewContext.performAndWait {
            found.name = senderName
            found.url = URL(string: url)
            found.epg = ""
            found.preview = preview
            found.timestamp = Date()
            do {
                try viewContext.save()
            } catch {
                print(error)
            }
        }
        // 2. clear fields
        self.sender = ""
        self.senderName = ""
        self.preview = true
        // 3. add to current channellist
        channelList[senderName] = [url, "", preview ? "1" : "0"]
        keys = Array(channelList.keys).sorted()
    }
    
    /// Replaces the persisted channel list with the built-in defaults.
    func resetChannelsToDefault() {
        // use default channel list to rebuild channels
        // delete database
        entities.forEach(viewContext.delete)
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        self.renewChannels()
    }
    
    /// Rebuilds the channel database from `defaultChannelList`.
    func renewChannels() {
        // recreate database
        for (key, value) in defaultChannelList {
            let ch = Channel(context: self.viewContext)
            ch.name = key
            ch.url = URL(string: value[0])
            ch.epg = value[1]
            ch.preview = value[2] == "1" ? true : false
            ch.timestamp = Date()
            do {
                try self.viewContext.save()
            } catch {
                print(error)
            }
        }
        // create new channelList
        channelList = defaultChannelList
    }
    
    /// Deletes the selected channel rows from persistence and memory.
    private func deleteFromDatabase(at offsets: IndexSet) {
        offsets.map { entities[$0] }.forEach(viewContext.delete)
        let delSender = entities[offsets.first!] as Channel
        channelList.removeValue(forKey: delSender.name!)
        keys = Array(channelList.keys).sorted()
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            print(error)
        }
    }
    
    /// Starts a remote refresh of the channel list.
    func refreshChannelsFromWeb() {
        self.getChannels()
    }
    
    /// Placeholder hook for loading channels from a remote source.
    private func getChannels() {
        // Implementation for getting channels from web
    }
    
    /// Fetches raw HTML from a URL and returns it via a completion handler.
    private func getHTML(aURL: String, completion: ( (String) -> (Void) )?) {
        let url = URL(string: aURL)!
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else { return }
            let tempHTML = String(data: data, encoding: .utf8)!
            
            completion?(tempHTML)
        }
        task.resume()
    }
}
