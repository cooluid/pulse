import Foundation

public enum PulseMediaPath {
    public enum Directory: String, CaseIterable, Sendable {
        case originals
        case thumbnails
    }

    public static func make(directory: Directory, storageID: UUID) -> String {
        "\(directory.rawValue)/\(storageID.uuidString.lowercased()).jpg"
    }

    public static func isValid(_ path: String, directory: Directory) -> Bool {
        guard Self.directory(for: path) == directory else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        let filename = String(components[1])
        guard filename.hasSuffix(".jpg") else { return false }
        let identifier = String(filename.dropLast(4))
        guard let storageID = UUID(uuidString: identifier) else { return false }
        return identifier == storageID.uuidString.lowercased()
    }

    public static func isValidStoredPath(_ path: String) -> Bool {
        guard let directory = directory(for: path) else { return false }
        return isValid(path, directory: directory)
    }

    public static func directory(for path: String) -> Directory? {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains(".."),
              !path.contains("\\") else {
            return nil
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2 else { return nil }
        return Directory(rawValue: String(components[0]))
    }
}
