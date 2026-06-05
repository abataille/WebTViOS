//
//  ImprovedChannelView.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 14.05.25.
//  Copyright © 2025 Raymund Vorwerk. All rights reserved.
//


//
//  ImprovedChannelView.swift
//  WebTV
//
//  Created based on original ChannelView.swift
//  Copyright © 2024-2025 All rights reserved.

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

/// Single in-memory source of truth for channel data while keeping legacy globals synchronized.
@MainActor
final class ChannelStore: ObservableObject {
    @Published private(set) var names: [String] = []
    @Published private(set) var entries: [String: [String]] = [:]

    func load(from viewContext: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Channel> = Channel.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Channel.name, ascending: true)
        ]

        do {
            let entities = try viewContext.fetch(fetchRequest)
            if entities.isEmpty {
                replaceAll(with: defaultChannelList)
            } else {
                replaceAll(with: Dictionary(uniqueKeysWithValues: entities.compactMap { channel in
                    guard let name = channel.name, !name.isEmpty else { return nil }
                    return (
                        name,
                        [
                            channel.url?.absoluteString ?? "",
                            "",
                            channel.preview ? "1" : "0",
                        ]
                    )
                }))
            }
        } catch {
            replaceAll(with: defaultChannelList)
        }
    }

    func replaceAll(with newEntries: [String: [String]]) {
        entries = newEntries
        names = Array(newEntries.keys).sorted()
        channelList = newEntries
    }

    func upsert(name: String, url: String, preview: Bool, replacing oldName: String? = nil) {
        if let oldName, oldName != name {
            entries.removeValue(forKey: oldName)
        }
        entries[name] = [url, "", preview ? "1" : "0"]
        syncLegacyChannelList()
    }

    func remove(name: String) {
        entries.removeValue(forKey: name)
        syncLegacyChannelList()
    }

    private func syncLegacyChannelList() {
        names = Array(entries.keys).sorted()
        channelList = entries
    }
}


/// Modern channel management sheet for adding, editing, and deleting channels.
struct ImprovedChannelView: View {
    // MARK: - Properties
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismissAction
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Channel.name, ascending: true)],
        animation: .default)
    private var channels: FetchedResults<Channel>
    
    @ObservedObject var channelStore: ChannelStore
    @State private var selectedTab: Int = 0
    
    // Channel form fields
    @State private var channelName: String = ""
    @State private var channelURL: String = ""
    @State private var enablePreview: Bool = true
    @State private var isEditing: Bool = false
    @State private var editingChannel: Channel? = nil
    
    // Alerts
    @State private var showingResetAlert = false
    @State private var showingRefreshAlert = false
    @State private var showingDeleteAlert = false
    @State private var validationMessage: String?
    @State private var channelToDelete: Channel? = nil
    @State private var searchText = ""
    
    // MARK: - Computed Properties
    private var filteredChannels: [Channel] {
        if searchText.isEmpty {
            return Array(channels)
        } else {
            return channels.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var formIsValid: Bool {
        return !channelName.trimmed.isEmpty && URL(string: channelURL.trimmed) != nil
    }
    
    // MARK: - Body
    /// Renders the channel management interface.
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom segmented picker at the top
                CustomSegmentedPicker(
                    selection: $selectedTab,
                    options: [
                        String(localized: "Channels"),
                        String(localized: "Add/Edit")
                    ]
                )
                .padding(.horizontal)
                .padding(.top)
                
                TabView(selection: $selectedTab) {
                    // MARK: - Channels List Tab
                    channelsListView
                        .tag(0)
                    
                    // MARK: - Add/Edit Channel Tab
                    addEditChannelView
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedTab)
            }
            .navigationTitle(String(localized: "Channel Manager"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismissAction()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            showingResetAlert = true
                        } label: {
                            Label(String(localized: "Reset to Default"), systemImage: "arrow.counterclockwise")
                        }
                        
                        Button {
                            showingRefreshAlert = true
                        } label: {
                            Label(String(localized: "Refresh from Web"), systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(String(localized: "Are you sure?"), isPresented: $showingResetAlert) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Reset"), role: .destructive) {
                    resetChannelsToDefault()
                }
            } message: {
                Text(String(localized: "This will reset all channels to default values. This action cannot be undone."))
            }
            .alert(String(localized: "Are you sure?"), isPresented: $showingRefreshAlert) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Refresh"), role: .destructive) {
                    refreshChannelsFromWeb()
                }
            } message: {
                Text(String(localized: "This will update channels from the web source."))
            }
            .alert(String(localized: "Confirm Deletion"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Delete"), role: .destructive) {
                    if let channel = channelToDelete {
                        deleteChannel(channel)
                    }
                }
            } message: {
                if let name = channelToDelete?.name {
                    Text(String(localized: "Are you sure you want to delete '\(name)'?"))
                }
            }
        }
    }
    
    // MARK: - Channels List View
    private var channelsListView: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField(String(localized: "Search channels..."), text: $searchText)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Channel list
            List {
                ForEach(filteredChannels, id: \.self) { channel in
                    channelCell(for: channel)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                channelToDelete = channel
                                showingDeleteAlert = true
                            } label: {
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                            
                            Button {
                                editChannel(channel)
                            } label: {
                                Label(String(localized: "Edit"), systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Add/Edit Channel View
    private var addEditChannelView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Channel Name"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField(String(localized: "Enter channel name"), text: $channelName)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Stream URL"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField(String(localized: "Enter stream URL"), text: $channelURL)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                .padding(.vertical, 4)
                
                
                Toggle(String(localized: "Enable Live Preview"), isOn: $enablePreview)
                    .padding(.vertical, 8)
            }
            
            Section {
                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    saveChannel()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: isEditing ? "square.and.pencil" : "plus.circle")
                        Text(isEditing ? String(localized: "Update Channel") : String(localized: "Add Channel"))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .background(formIsValid ? Color.blue : Color.gray.opacity(0.5))
                    .cornerRadius(10)
                }
                .disabled(!formIsValid)
                
                if isEditing {
                    Button {
                        cancelEdit()
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "Cancel"))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Channel Cell
    private func channelCell(for channel: Channel) -> some View {
        HStack(spacing: 15) {
            // Channel preview indicator
            Circle()
                .fill(channel.preview ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 12, height: 12)
            
            // Channel details
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name ?? String(localized: "Unnamed Channel"))
                    .font(.headline)
                
                if let url = channel.url?.absoluteString {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
            }
            
            Spacer()
            
            // Edit button
            Button {
                editChannel(channel)
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Circle().fill(Color.blue.opacity(0.1)))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Custom Segmented Picker
    /// Segmented control used to switch between list and edit tabs.
    struct CustomSegmentedPicker: View {
        @Binding var selection: Int
        let options: [String]
        
        /// Renders the segmented button row.
        var body: some View {
            HStack {
                ForEach(0..<options.count, id: \.self) { index in
                    Button {
                        withAnimation {
                            selection = index
                        }
                    } label: {
                        Text(options[index])
                            .font(.system(size: 16, weight: selection == index ? .semibold : .regular))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(selection == index ? .white : .primary)
                    .background(selection == index ? Color.blue : Color.clear)
                    .cornerRadius(8)
                }
            }
            .padding(4)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Methods
    /// Saves a new or edited channel back to Core Data and the in-memory list.
    private func saveChannel() {
        let trimmedName = channelName.trimmed
        let trimmedURL = channelURL.trimmed
        let oldName = editingChannel?.name

        guard !trimmedName.isEmpty else {
            validationMessage = String(localized: "Channel name is required.")
            return
        }

        guard let url = URL(string: trimmedURL), url.scheme != nil else {
            validationMessage = String(localized: "Enter a valid stream URL.")
            return
        }

        if channels.contains(where: { channel in
            channel != editingChannel && channel.name?.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            validationMessage = String(localized: "A channel with this name already exists.")
            return
        }

        if isEditing, let channel = editingChannel {
            // Update existing channel
            channel.name = trimmedName
            channel.url = url
            channel.epg = ""
            channel.preview = enablePreview
            channel.timestamp = Date()

            do {
                try viewContext.save()
                // Update channel list
                channelStore.upsert(
                    name: trimmedName,
                    url: trimmedURL,
                    preview: enablePreview,
                    replacing: oldName
                )

                // Reset form
                resetForm()
            } catch {
                print("Error updating channel: \(error)")
            }
        } else {
            // Create new channel
            let newChannel = Channel(context: viewContext)
            newChannel.name = trimmedName
            newChannel.url = url
            newChannel.epg = ""
            newChannel.preview = enablePreview
            newChannel.timestamp = Date()
            
            do {
                try viewContext.save()
                // Update channel list
                channelStore.upsert(
                    name: trimmedName,
                    url: trimmedURL,
                    preview: enablePreview
                )
                
                // Reset form
                resetForm()
            } catch {
                print("Error adding channel: \(error)")
            }
        }
    }
    
    /// Loads an existing channel into the edit form.
    private func editChannel(_ channel: Channel) {
        // Switch to the add/edit tab
        selectedTab = 1
        
        // Fill form with channel details
        channelName = channel.name ?? ""
        channelURL = channel.url?.absoluteString ?? ""
        enablePreview = channel.preview
        
        // Set editing state
        isEditing = true
        editingChannel = channel
    }
    
    /// Leaves edit mode and clears the form.
    private func cancelEdit() {
        resetForm()
    }
    
    /// Resets the channel form to its default values.
    private func resetForm() {
        channelName = ""
        channelURL = ""
        enablePreview = true
        isEditing = false
        editingChannel = nil
        validationMessage = nil
    }
    
    /// Deletes a channel from Core Data and the in-memory list.
    private func deleteChannel(_ channel: Channel) {
        // Remove from Core Data
        viewContext.delete(channel)
        
        // Remove from channel list
        if let name = channel.name {
            channelStore.remove(name: name)
        }
        
        // Save changes
        do {
            try viewContext.save()
        } catch {
            print("Error deleting channel: \(error)")
        }
    }
    
    /// Replaces the current channel set with the default list.
    private func resetChannelsToDefault() {
        // Delete all current channels
        channels.forEach(viewContext.delete)
        
        do {
            try viewContext.save()
            renewChannels()
        } catch {
            print("Error resetting channels: \(error)")
        }
    }
    
    /// Recreates the default channel set in persistent storage.
    private func renewChannels() {
        // Recreate channels from default list
        for (key, value) in defaultChannelList {
            let ch = Channel(context: viewContext)
            ch.name = key
            ch.url = URL(string: value[0])
            ch.epg = value[1]
            ch.preview = value[2] == "1"
            ch.timestamp = Date()
            
            do {
                try viewContext.save()
            } catch {
                print("Error creating default channel: \(error)")
            }
        }
        
        // Update channel list
        channelStore.replaceAll(with: defaultChannelList)
    }
    
    /// Starts a remote refresh for channel definitions.
    private func refreshChannelsFromWeb() {
        // Implement channel refresh logic
        getChannels()
    }
    
    /// Placeholder for the remote channel fetch implementation.
    private func getChannels() {
        // Web fetch implementation would go here
    }
}

// MARK: - Preview
/// Preview provider for the improved channel manager.
struct ImprovedChannelView_Previews: PreviewProvider {
    static var previews: some View {
        ImprovedChannelView(channelStore: ChannelStore())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

// Placeholder for persistence controller
/// Lightweight preview persistence container used by SwiftUI previews.
struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // Add sample data if needed
        return controller
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WebTV")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
