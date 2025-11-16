import Foundation

enum AttachmentUploader {
    static func upload(_ drafts: [AttachmentDraft]) async throws -> [AttachmentReference] {
        guard !drafts.isEmpty else { return [] }

        var references: [AttachmentReference] = []
        references.reserveCapacity(drafts.count)

        for draft in drafts {
            let data = try Data(contentsOf: draft.fileURL, options: [.mappedIfSafe])
            let storageKey = try await StorageHelper.upload(data, filename: draft.fileName)
            let reference = AttachmentReference(
                storageKey: storageKey,
                fileName: draft.fileName,
                contentType: draft.contentType,
                fileSize: draft.fileSize ?? data.count
            )
            references.append(reference)
        }

        return references
    }
}
