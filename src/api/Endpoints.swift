import Foundation

/// Pages are opened only in response to a user action. No application backend is contacted.
enum Endpoints {
    static let website = "https://github.com/stephen2754/Free-Alt-Tab"
    static let releasesUrl = website + "/releases"
    static let feedbackUrl = website + "/issues/new/choose"
    static let supportUrl = website
}
