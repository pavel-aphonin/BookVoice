//
//  SecurityScopedAccess.swift
//  BookVoice
//

import Foundation

enum SecurityScopedAccess {
    /// Create a security-scoped bookmark for a URL
    static func createBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolve a security-scoped bookmark back to a URL
    static func resolveBookmark(_ bookmarkData: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }

    /// Access a URL using a security-scoped bookmark, performing work within the scope
    static func withSecurityScopedAccess<T>(
        to bookmarkData: Data,
        perform work: (URL) throws -> T
    ) throws -> T {
        let (url, _) = try resolveBookmark(bookmarkData)
        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityScopedAccessError.accessDenied(url.path)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try work(url)
    }
}

enum SecurityScopedAccessError: LocalizedError {
    case accessDenied(String)
    case bookmarkStale(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied(let path): "Access denied to: \(path)"
        case .bookmarkStale(let path): "Bookmark is stale for: \(path)"
        }
    }
}
