import Darwin
import Foundation

/// Watches interface events on a route socket, so awdl0 can be taken down the moment macOS brings
/// it back instead of staying up until the next tick.
enum AWDLWatcher {
    /// Calls `onUp` on a thread of its own each time awdl0 is reported up.
    static func start(onUp: @escaping () -> Void) {
        Thread {
            let fd = socket(PF_ROUTE, SOCK_RAW, 0)
            guard fd >= 0 else {
                Store.log("cannot watch awdl0 (errno \(errno)); falling back to checking every tick")
                return
            }
            var buffer = [UInt8](repeating: 0, count: 2048)
            while true {
                let count = read(fd, &buffer, buffer.count)
                if count < 0 {
                    if errno == EINTR { continue }
                    Store.log("stopped watching awdl0 (errno \(errno)); falling back to checking every tick")
                    close(fd)
                    return
                }
                guard count >= MemoryLayout<if_msghdr>.size else { continue }
                let message = buffer.withUnsafeBytes { $0.loadUnaligned(as: if_msghdr.self) }
                // The interface index can change if awdl0 is ever recreated, so look it up each time.
                guard Int32(message.ifm_type) == RTM_IFINFO,
                      UInt32(message.ifm_index) == if_nametoindex("awdl0"),
                      message.ifm_flags & IFF_UP != 0 else { continue }
                // Same as the agent loop: no run loop here, so drain the Pipes `sh` leaves behind.
                autoreleasepool { onUp() }
            }
        }.start()
    }
}
