import Foundation
import UniformTypeIdentifiers

enum AttachmentDraftFactory {
    static func makeDraft(fromDocumentAt url: URL) -> AttachmentDraft? {
        var didAccess = false
        if url.startAccessingSecurityScopedResource() {
            didAccess = true
        }
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let originalName = url.lastPathComponent.nilIfEmpty ?? "Attachment-\(UUID().uuidString)"
        let sanitizedName = sanitizeFileName(originalName)

        do {
            let destination = temporaryURL(for: sanitizedName)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: url, to: destination)

            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard fileSize <= AttachmentConstraints.maxFileSizeBytes else {
                try? FileManager.default.removeItem(at: destination)
                print("AttachmentDraftFactory: file exceeds maximum size.")
                return nil
            }

            let mimeType = inferContentType(forExtension: destination.pathExtension)

            return AttachmentDraft(
                fileURL: destination,
                fileName: sanitizedName,
                contentType: mimeType,
                fileSize: fileSize
            )
        } catch {
            print("AttachmentDraftFactory: failed to copy document - \(error.localizedDescription)")
            return nil
        }
    }

    private static func temporaryURL(for fileName: String) -> URL {
        let ext = (fileName as NSString).pathExtension
        var url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Attachment-\(UUID().uuidString)")
        if !ext.isEmpty {
            url = url.appendingPathExtension(ext)
        }
        return url
    }

    private static func sanitizeFileName(_ name: String) -> String {
        let disallowed = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        var sanitized = name.components(separatedBy: disallowed).joined(separator: "-")
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        if sanitized.isEmpty {
            sanitized = "Attachment-\(UUID().uuidString)"
        }
        return sanitized
    }

    private static func inferContentType(forExtension ext: String) -> String? {
        guard !ext.isEmpty else { return nil }
        if let type = UTType(filenameExtension: ext.lowercased()) {
            return type.preferredMIMEType
        }
        return nil
    }
}
