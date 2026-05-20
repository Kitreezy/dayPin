import Foundation

extension Notification {
    /// Extracts an optional folder UUID from the notification's userInfo.
    /// Set by MainContainerViewController when the "+" grid is opened from a folder context.
    var folderID: UUID? {
        userInfo?["folderID"] as? UUID
    }
}
