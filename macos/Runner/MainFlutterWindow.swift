import Cocoa
import AVFoundation
import Accelerate
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var videoExporter: VideoExporter?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Native window polish.
    self.title = "Tactics Animator"
    self.minSize = NSSize(width: 1100, height: 720)

    // Video export channel (AVFoundation H.264 encoder).
    let exporter = VideoExporter()
    self.videoExporter = exporter
    let channel = FlutterMethodChannel(
      name: "tactics/video_exporter",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      exporter.handle(call, result: result)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

/// Encodes RGBA frames received from Flutter into an H.264 .mp4 using
/// AVFoundation. Frames arrive one at a time, in order, over a method channel.
class VideoExporter {
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var frameIndex: Int64 = 0
  private var fps: Int32 = 30
  private var width = 1920
  private var height = 1080

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start": start(call, result)
    case "addFrame": addFrame(call, result)
    case "finish": finish(result)
    case "cancel": cancel(result)
    case "reveal": reveal(call, result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func fail(_ result: FlutterResult, _ message: String) {
    result(FlutterError(code: "export_error", message: message, details: nil))
  }

  private func start(_ call: FlutterMethodCall, _ result: FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let w = args["width"] as? Int,
          let h = args["height"] as? Int,
          let f = args["fps"] as? Int else {
      fail(result, "invalid start arguments"); return
    }
    let bitrate = (args["bitrate"] as? Int) ?? Int(Double(w * h) * Double(f) * 0.20)

    width = w
    height = h
    fps = Int32(f)
    frameIndex = 0

    let url = URL(fileURLWithPath: path)
    try? FileManager.default.removeItem(at: url)

    do {
      writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    } catch {
      fail(result, "could not create writer: \(error.localizedDescription)"); return
    }

    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: w,
      AVVideoHeightKey: h,
      // Accurate Rec.709 color so exported greens/reds match the editor.
      AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ],
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoAllowFrameReorderingKey: true, // B-frames: better quality per bit
        AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
        AVVideoExpectedSourceFrameRateKey: Int(fps),
      ],
    ]

    let inp = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    inp.expectsMediaDataInRealTime = false

    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
      kCVPixelBufferWidthKey as String: w,
      kCVPixelBufferHeightKey as String: h,
    ]
    adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: inp,
                                                   sourcePixelBufferAttributes: attrs)

    guard let writer = writer, writer.canAdd(inp) else {
      fail(result, "cannot add input"); return
    }
    writer.add(inp)
    input = inp

    guard writer.startWriting() else {
      fail(result, "startWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
      return
    }
    writer.startSession(atSourceTime: .zero)
    result(nil)
  }

  private func addFrame(_ call: FlutterMethodCall, _ result: FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let typed = args["rgba"] as? FlutterStandardTypedData,
          let adaptor = adaptor, let input = input else {
      fail(result, "invalid addFrame arguments"); return
    }

    // Wait until the encoder is ready for more data.
    var spins = 0
    while !input.isReadyForMoreMediaData {
      usleep(1000)
      spins += 1
      if spins > 10000 { fail(result, "encoder timeout"); return } // ~10s guard
    }

    guard let pool = adaptor.pixelBufferPool else {
      fail(result, "no pixel buffer pool"); return
    }

    var pbOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pbOut)
    guard let pb = pbOut else { fail(result, "could not create pixel buffer"); return }

    CVPixelBufferLockBaseAddress(pb, [])
    let dstBase = CVPixelBufferGetBaseAddress(pb)!
    let dstBpr = CVPixelBufferGetBytesPerRow(pb)
    let srcBpr = width * 4

    // Swap R<->B (RGBA -> BGRA) with Accelerate — far faster than a per-pixel
    // loop, and it respects the pixel buffer's row padding.
    let data = typed.data
    data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
      guard let srcBase = raw.baseAddress else { return }
      var srcBuf = vImage_Buffer(
        data: UnsafeMutableRawPointer(mutating: srcBase),
        height: vImagePixelCount(height),
        width: vImagePixelCount(width),
        rowBytes: srcBpr)
      var dstBuf = vImage_Buffer(
        data: dstBase,
        height: vImagePixelCount(height),
        width: vImagePixelCount(width),
        rowBytes: dstBpr)
      // dst[i] = src[map[i]]: BGRA from RGBA.
      let map: [UInt8] = [2, 1, 0, 3]
      vImagePermuteChannels_ARGB8888(&srcBuf, &dstBuf, map, vImage_Flags(kvImageNoFlags))
    }
    CVPixelBufferUnlockBaseAddress(pb, [])

    let time = CMTime(value: frameIndex, timescale: fps)
    if !adaptor.append(pb, withPresentationTime: time) {
      fail(result, "append failed: \(writer?.error?.localizedDescription ?? "unknown")")
      return
    }
    frameIndex += 1
    result(nil)
  }

  private func finish(_ result: @escaping FlutterResult) {
    guard let writer = writer, let input = input else { result(nil); return }
    input.markAsFinished()
    writer.finishWriting {
      let err = writer.status == .failed ? writer.error?.localizedDescription : nil
      DispatchQueue.main.async {
        if let err = err {
          result(FlutterError(code: "export_error", message: err, details: nil))
        } else {
          result(nil)
        }
      }
    }
    self.writer = nil
    self.input = nil
    self.adaptor = nil
  }

  private func reveal(_ call: FlutterMethodCall, _ result: FlutterResult) {
    if let args = call.arguments as? [String: Any], let path = args["path"] as? String {
      NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
    result(nil)
  }

  private func cancel(_ result: FlutterResult) {
    input?.markAsFinished()
    writer?.cancelWriting()
    writer = nil
    input = nil
    adaptor = nil
    result(nil)
  }
}
