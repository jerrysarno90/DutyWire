//
//  AuditLogger.swift
//  ShiftlinkMain
//
//  Created by Codex on 11/11/25.
//

import Foundation

struct AuditEvent: Identifiable {
    enum Category: String {
        case authentication
        case onboarding
        case roster
        case system
    }

    let id = UUID()
    let timestamp: Date
    let category: Category
    let tenantId: String?
    let message: String
    let metadata: [String: String]

    init(
        timestamp: Date = Date(),
        category: Category,
        tenantId: String?,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.category = category
        self.tenantId = tenantId
        self.message = message
        self.metadata = metadata
    }
}

/// Simple in-memory audit log. Swappable with CloudWatch/Firehose once the backend is ready.
final class AuditLogger: ObservableObject {
    static let shared = AuditLogger()

    @Published private(set) var events: [AuditEvent] = []
    private let queue = DispatchQueue(label: "com.dutywire.auditlogger", qos: .utility)

    func record(
        category: AuditEvent.Category,
        tenantId: String?,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let event = AuditEvent(
            category: category,
            tenantId: tenantId,
            message: message,
            metadata: metadata
        )
        queue.async { [weak self] in
            self?.events.append(event)
        }
    }
}
