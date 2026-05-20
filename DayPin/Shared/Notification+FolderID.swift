import Foundation

extension Notification {
    // Set by MainContainerViewController when the "+" grid is opened from a folder context.
    var folderID: UUID? {
        userInfo?["folderID"] as? UUID
    }
}
