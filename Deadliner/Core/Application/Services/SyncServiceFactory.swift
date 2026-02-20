//
//  SyncServiceFactory.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

enum SyncServiceImpl: String {
    case v1 = "v1"
}

enum SyncServiceFactory {
    static func makeV1WebDAV(
        db: DatabaseHelper,
        web: WebDAVClient
    ) -> any SyncService {
        SyncServiceV1(db: db, web: web)
    }
    
    static func make(
        db: DatabaseHelper,
        web: WebDAVClient,
        impl: SyncServiceImpl
    ) -> any SyncService {
        switch (impl) {
        case .v1:
            return makeV1WebDAV(db: db, web: web)
        }
    }
}
