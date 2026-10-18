import Foundation

/// Runs a command and captures stdout and stderr together.
@discardableResult
func sh(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do { try process.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    try? pipe.fileHandleForReading.close()
    process.waitUntilExit()
    let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    return (process.terminationStatus, output)
}

/// Runs a command attached to the caller's terminal, so `sudo` can prompt for a password.
/// Uses posix_spawn rather than Process: Process starts the child in a new process group,
/// which is not the terminal's foreground group, so sudo can neither turn off echo nor read input.
@discardableResult
public func interactive(_ path: String, _ args: [String]) -> Int32 {
    let argv = ([path] + args).map { strdup($0) } + [nil]
    defer { argv.forEach { free($0) } }
    var pid: pid_t = 0
    guard posix_spawn(&pid, path, nil, nil, argv, environ) == 0 else { return -1 }
    var status: Int32 = 0
    while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
    // WIFEXITED / WEXITSTATUS are macros Swift cannot import.
    return status & 0x7f == 0 ? (status >> 8) & 0xff : -1
}
