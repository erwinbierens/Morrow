import CryptoKit
import Foundation

struct AppVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ tag: String) {
        let normalized = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let parts = normalized.split(separator: ".")
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2])
        else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

struct MorrowUpdate {
    let version: AppVersion
    let packageURL: URL
    let sha256: String
}

enum UpdateServiceError: LocalizedError {
    case invalidResponse
    case untrustedPackageURL
    case invalidDigest

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "GitHub did not return a valid release list."
        case .untrustedPackageURL: "The installer link does not point to the Morrow GitHub repository."
        case .invalidDigest: "The downloaded installer did not match GitHub's SHA-256 checksum."
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let draft: Bool
    let assets: [GitHubAsset]
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: URL
    let digest: String?
}

enum UpdateService {
    static func newestUpdate(currentVersion: String) async throws -> MorrowUpdate? {
        guard let current = AppVersion(currentVersion) else { return nil }
        let url = URL(string: "https://api.github.com/repos/erwinbierens/Morrow/releases?per_page=20")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Morrow/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw UpdateServiceError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let releases = try decoder.decode([GitHubRelease].self, from: data)

        return releases.compactMap { release -> MorrowUpdate? in
            guard !release.draft,
                  let version = AppVersion(release.tagName), version > current,
                  let asset = release.assets.first(where: { $0.name == "Morrow.pkg" }),
                  asset.browserDownloadUrl.scheme == "https",
                  asset.browserDownloadUrl.host == "github.com",
                  asset.browserDownloadUrl.path.hasPrefix("/erwinbierens/Morrow/releases/download/"),
                  let digest = asset.digest?.lowercased(), digest.hasPrefix("sha256:")
            else { return nil }
            return MorrowUpdate(version: version, packageURL: asset.browserDownloadUrl, sha256: digest)
        }.max(by: { $0.version < $1.version })
    }

    static func downloadInstaller(for update: MorrowUpdate) async throws -> URL {
        guard update.packageURL.scheme == "https",
              update.packageURL.host == "github.com",
              update.packageURL.path.hasPrefix("/erwinbierens/Morrow/releases/download/")
        else { throw UpdateServiceError.untrustedPackageURL }

        let (data, response) = try await URLSession.shared.data(from: update.packageURL)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw UpdateServiceError.invalidResponse
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard "sha256:\(digest)" == update.sha256 else { throw UpdateServiceError.invalidDigest }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Morrow-\(update.version).pkg")
        try data.write(to: destination, options: .atomic)
        return destination
    }
}
