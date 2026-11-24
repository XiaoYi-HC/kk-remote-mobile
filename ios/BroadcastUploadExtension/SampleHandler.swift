import ReplayKit
import CoreImage
import CoreMedia
import Darwin

/// 通过 App Group 内的 Unix Socket 把 ReplayKit 画面发送给主 App 的 flutter_webrtc。
/// 协议与 flutter_webrtc 的 FlutterSocketConnectionFrameReader 保持一致：
/// HTTP 响应头 + JPEG 帧数据。
final class SocketWriter {
    private let appGroup: String
    private let fileName: String
    private var fd: Int32 = -1
    private let lock = NSLock()

    init(appGroup: String, fileName: String = "rtc_SSFD") {
        self.appGroup = appGroup
        self.fileName = fileName
    }

    func connectWithRetry(attempts: Int = 20) -> Bool {
        for _ in 0..<attempts {
            if connectOnce() { return true }
            usleep(100_000)
        }
        return false
    }

    private func connectOnce() -> Bool {
        close()
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) else {
            return false
        }
        let path = container.appendingPathComponent(fileName).path
        let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        if socketFD < 0 { return false }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        if pathBytes.count > capacity {
            Darwin.close(socketFD)
            return false
        }
        withUnsafeMutablePointer(to: &addr.sun_path.0) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                pathBytes.withUnsafeBufferPointer { src in
                    guard let base = src.baseAddress else { return }
                    dst.update(from: base, count: pathBytes.count)
                }
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.connect(socketFD, sa, size)
            }
        }
        if result != 0 {
            Darwin.close(socketFD)
            return false
        }
        fd = socketFD
        return true
    }

    func send(header: String, body: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard fd >= 0 else { return }
        var packet = Data(header.utf8)
        packet.append(body)
        packet.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < packet.count {
                let written = Darwin.write(fd, base.advanced(by: offset), packet.count - offset)
                if written <= 0 { return }
                offset += written
            }
        }
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }
}

class SampleHandler: RPBroadcastSampleHandler {
    private let writer = SocketWriter(appGroup: "group.com.kk.remote")
    private let ciContext = CIContext()
    private var lastSentAt: TimeInterval = 0
    private let minInterval: TimeInterval = 1.0 / 20.0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        _ = writer.connectWithRetry()
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        writer.close()
    }

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        guard sampleBufferType == .video,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let now = Date().timeIntervalSinceReferenceDate
        if now - lastSentAt < minInterval { return }
        lastSentAt = now

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let data = ciContext.jpegRepresentation(
                of: image,
                colorSpace: colorSpace,
                options: [:]
              ) else {
            return
        }
        var orientation = 1
        if let value = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber {
            orientation = value.intValue
        }
        let header = "HTTP/1.1 200 OK\r\n"
            + "Content-Length: \(data.count)\r\n"
            + "Buffer-Width: \(width)\r\n"
            + "Buffer-Height: \(height)\r\n"
            + "Buffer-Orientation: \(orientation)\r\n\r\n"
        writer.send(header: header, body: data)
    }
}
