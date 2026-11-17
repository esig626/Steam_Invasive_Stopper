import AppKit
import Foundation

// This programme runs as a LaunchAgent in the signed-in user's GUI session.
// It listens for Steam to quit rather than checking on a timer.
private let steamBundleID = "com.valvesoftware.steam"
private let ipcService = "com.valvesoftware.steam.ipctool"

@discardableResult
private func execute(_ executable: String, _ arguments: [String]) -> Int32? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        return nil
    }
}

private func steamIsRunning() -> Bool {
    if !NSRunningApplication.runningApplications(withBundleIdentifier: steamBundleID).isEmpty {
        return true
    }

    // A missing process gives exit code 1. Treat all errors as "running"
    // so that a failed process check cannot remove a needed service.
    return execute("/usr/bin/pgrep", ["-x", "steam_osx"]) != 1
}

private func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    FileHandle.standardOutput.write(Data("\(timestamp) \(message)\n".utf8))
}

private func cleanUpAfterQuit() {
    guard !steamIsRunning() else {
        log("Steam is running again; cleanup skipped")
        return
    }

    guard execute("/bin/launchctl", ["list", ipcService]) == 0 else {
        log("No leftover ipctool service")
        return
    }

    // Recheck immediately before removing anything.
    guard !steamIsRunning() else {
        log("Steam restarted; cleanup skipped")
        return
    }

    guard execute("/bin/launchctl", ["remove", ipcService]) == 0 else {
        log("Unable to remove ipctool service")
        return
    }

    // launchctl remove can return before the process fully exits.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        if execute("/bin/launchctl", ["list", ipcService]) != 0 {
            log("Removed leftover ipctool service")
        } else {
            log("Removal requested but ipctool is still registered")
        }
    }
}

let observer = NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didTerminateApplicationNotification,
    object: nil,
    queue: .main
) { notification in
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
        as? NSRunningApplication,
        app.bundleIdentifier == steamBundleID else {
        return
    }

    log("Steam terminated")
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        cleanUpAfterQuit()
    }
}

log("Steam termination listener started")
withExtendedLifetime(observer) {
    RunLoop.main.run()
}
