import Foundation

struct AttachmentDraft: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    let fileName: String
    let contentType: String?
    let fileSize: Int?

    init(
        id: UUID = UUID(),
        fileURL: URL,
        fileName: String,
        contentType: String?,
        fileSize: Int?
    ) {
        self.id = id
        self.fileURL = fileURL
        self.fileName = fileName
        self.contentType = contentType
        self.fileSize = fileSize
    }

    var formattedSizeLabel: String? {
        guard let fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

enum AttachmentConstraints {
    static let maxAttachmentCount = 10
    static let maxFileSizeBytes = 50 * 1024 * 1024 // 50 MB
    static let allowedFormatsDescription = "JPG, PNG, HEIC, MP4, MOV, PDF, DOC, DOCX, XLSX • ≤ 50 MB each"
}
