import FileSystem
import FileSystemTesting
import Path
import Testing

@testable import tuist

struct DependenciesTests {
    private let fileSystem = FileSystem()

    @Test(.inTemporaryDirectory)
    func withLoggerForNoora_runsActionWhenLogFileWasDeleted() async throws {
        let temporaryDirectory = try #require(FileSystem.temporaryTestDirectory)
        let logFilePath = temporaryDirectory.appending(component: "logs.txt")
        try await fileSystem.touch(logFilePath)
        try await fileSystem.remove(logFilePath)

        var didRunAction = false

        try await withLoggerForNoora(logFilePath: logFilePath) {
            didRunAction = true
        }

        #expect(didRunAction)
        #expect(try await fileSystem.exists(logFilePath))
    }
}
