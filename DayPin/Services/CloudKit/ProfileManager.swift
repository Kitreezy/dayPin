import Foundation
import UIKit
import CloudKit

// Manages the current user's display name and avatar photo.

final class ProfileManager {

    static let shared = ProfileManager()
    private init() { loadFromCache() }

    // MARK: - State

    private(set) var displayName: String = ""
    private(set) var email: String = ""
    private(set) var avatarImage: UIImage?

    private let cacheNameKey = "daypin.profile.displayName"
    private let cacheEmailKey = "daypin.profile.email"
    private let cacheAvatarKey = "daypin.profile.avatarData"

    // MARK: - Load from CloudKit

    func fetchProfile() async {
        do {
            let identity = try await CloudKitManager.shared.fetchUserIdentity()
            let name = identity.nameComponents.map {
                PersonNameComponentsFormatter().string(from: $0)
            } ?? ""
            let emailAddr = identity.lookupInfo?.emailAddress ?? ""

            await MainActor.run {
                self.displayName = name
                self.email = emailAddr
                UserDefaults.standard.set(name, forKey: self.cacheNameKey)
                UserDefaults.standard.set(emailAddr, forKey: self.cacheEmailKey)
                NotificationCenter.default.post(name: .dayPinProfileUpdated, object: nil)
            }
        } catch {
            // Use cached values if CloudKit is unavailable
        }
    }

    // MARK: - Avatar

    // Save a custom avatar to CloudKit UserRecord and cache locally
    func uploadAvatar(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        // Resize to 256x256 before uploading
        let resized = resized(image, to: CGSize(width: 256, height: 256))
        guard let resizedData = resized.jpegData(compressionQuality: 0.8) else { return }

        await MainActor.run {
            self.avatarImage = resized
            UserDefaults.standard.set(resizedData, forKey: self.cacheAvatarKey)
            NotificationCenter.default.post(name: .dayPinProfileUpdated, object: nil)
        }

        // Store in CloudKit user record
        do {
            let userRecordID = try await CloudKitManager.shared.container.userRecordID()
            let userRecord = try await CloudKitManager.shared.privateDB.record(for: userRecordID)
            if let asset = CloudKitManager.asset(from: data, filename: "avatar_\(userRecordID.recordName)") {
                userRecord["avatarAsset"] = asset
                try await CloudKitManager.shared.privateDB.save(userRecord)
            }
        } catch {
            // Avatar upload failed — local cache still updated
        }
    }

    func fetchAvatarFromCloud() async {
        do {
            let userRecordID = try await CloudKitManager.shared.container.userRecordID()
            let userRecord = try await CloudKitManager.shared.privateDB.record(for: userRecordID)
            if let data = CloudKitManager.data(from: userRecord["avatarAsset"] as? CKAsset),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.avatarImage = image
                    UserDefaults.standard.set(data, forKey: self.cacheAvatarKey)
                    NotificationCenter.default.post(name: .dayPinProfileUpdated, object: nil)
                }
            }
        } catch {}
    }

    // MARK: - Initials fallback

    var initials: String {
        let parts = displayName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        switch parts.count {
        case 0: return "?"
        case 1: return String(parts[0].prefix(1)).uppercased()
        default: return (String(parts[0].prefix(1)) + String(parts[parts.count - 1].prefix(1))).uppercased()
        }
    }

    // MARK: - Cache

    private func loadFromCache() {
        displayName = UserDefaults.standard.string(forKey: cacheNameKey) ?? ""
        email = UserDefaults.standard.string(forKey: cacheEmailKey) ?? ""
        if let data = UserDefaults.standard.data(forKey: cacheAvatarKey) {
            avatarImage = UIImage(data: data)
        }
    }

    // MARK: - Helpers

    private func resized(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let dayPinProfileUpdated = Notification.Name("dayPinProfileUpdated")
}
