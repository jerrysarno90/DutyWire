//
//  StorageHelper.swift
//  ShiftlinkMain
//
//  Created by Codex on 11/21/25.
//

import Foundation
import Amplify
import AWSS3StoragePlugin

enum StorageHelper {
    enum UploadError: LocalizedError {
        case authRequired

        var errorDescription: String? {
            "Please sign in to upload attachments."
        }
    }

    /// Uploads data inside the caller's private storage scope and returns the fully qualified storage path.
    static func upload(_ data: Data, filename: String) async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard session.isSignedIn else { throw UploadError.authRequired }

        let sanitizedName = filename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let objectName = "attachments/\(UUID().uuidString)-\(sanitizedName)"
        let path: IdentityIDStoragePath = .fromIdentityID { identityID in
            "private/\(identityID)/\(objectName)"
        }

        let uploadTask = Amplify.Storage.uploadData(path: path, data: data)
        let result = try await uploadTask.value
        return result
    }

    static func url(for storedPath: String) async throws -> URL {
        let resolvedPath = makeStoragePath(from: storedPath)
        return try await Amplify.Storage.getURL(path: resolvedPath)
    }

    static func downloadToTemp(for storedPath: String) async throws -> URL {
        let remoteURL = try await url(for: storedPath)
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(remoteURL.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private static func makeStoragePath(from storedValue: String) -> any StoragePath {
        if storedValue.hasPrefix("public/") ||
            storedValue.hasPrefix("protected/") ||
            storedValue.hasPrefix("private/") {
            return StringStoragePath.fromString(storedValue)
        } else {
            return IdentityIDStoragePath.fromIdentityID { identityID in
                "private/\(identityID)/\(storedValue)"
            }
        }
    }
}
