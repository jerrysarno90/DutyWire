import Foundation

struct AttachmentReference: Codable, Identifiable, Hashable {
    var storageKey: String
    var fileName: String
    var contentType: String?
    var fileSize: Int?

    var id: String { storageKey }
}

extension AttachmentReference {
    var metadataDictionary: [String: Any] {
        var payload: [String: Any] = [
            "storageKey": storageKey,
            "fileName": fileName
        ]
        if let contentType {
            payload["contentType"] = contentType
        }
        if let fileSize {
            payload["fileSize"] = fileSize
        }
        return payload
    }

    var formattedSizeLabel: String? {
        guard let fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}
