#if DEBUG
    import Foundation

    /// Opt-in namespace for permission and onboarding QA.
    enum QaLifecycleEnvironment {
        static let session = CommandLine.arguments.first { $0.hasPrefix("--qa-lifecycle-session=") }
            .flatMap { UUID(uuidString: String($0.dropFirst("--qa-lifecycle-session=".count)))?.uuidString }
        static var enabled: Bool {
            session != nil
        }
    }
#endif
