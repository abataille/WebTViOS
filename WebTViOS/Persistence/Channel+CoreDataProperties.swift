//
//  Channel+CoreDataProperties.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 09.12.20.
//  Copyright © 2020 Raymund Vorwerk. All rights reserved.
//
//

import Foundation
import CoreData


extension Channel {

    /// Creates the default fetch request for `Channel` entities.
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Channel> {
        return NSFetchRequest<Channel>(entityName: "Channel")
    }

    @NSManaged public var epg: String?
    @NSManaged public var name: String?
    @NSManaged public var preview: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var url: URL?

}

/// Marks `Channel` as identifiable for SwiftUI lists and ForEach.
extension Channel : Identifiable {

}
