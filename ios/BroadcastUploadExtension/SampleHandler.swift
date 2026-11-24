import ReplayKit
import CoreImage
import CoreMedia
import Darwin

/// 通过 127.0.0.1 TCP 把 ReplayKit 画面发送给主 App 的 flutter_webrtc。
/// 不使用 App Group，避免重签后没有 App Group 权限导致崩溃。
/// 协议与 flutter_webrtc 的 FlutterSocketConnectionFrameReader 保持一致：
/// HTTP 响应头 + JPEG 帧数据。
final class SocketWriter {
    private let port: UInt16
    private var fd: Int32 = -1
    private let lock = NSLock()

    init(port: UInt16 = 39876) {
        self.port = port
    }

    func connectWithRetry(attempts: Int = 20) -> Bool {
        for _ in 0..<attempts {
            if connectOnce() { return true }
            usleep(100_000)
        }
        return false
    }

    private func connectOnce() -> Bool {
        closeLocked()
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        if socketFD < 0 { return false }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let size = socklen_t(MemoryLayout<sockaddr_in>.size)
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
        // 主 App 的监听端口可能比扩展启动晚，连接一次即可，失败就丢帧，等下一帧再试。
        if fd < 0 && !connectOnce() { return }
        var packet = Data(header.utf8)
        packet.append(body)
        packet.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < packet.count {
                let written = Darwin.write(fd, base.advanced(by: offset), packet.count - offset)
                if written <= 0 {
                    closeLocked()
                    return
                }
                offset += written
            }
        }
    }

    private func closeLocked() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        closeLocked()
    }
}

class SampleHandler: RPBroadcastSampleHandler {
    private let writer = SocketWriter()
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
