import UIKit
import Flutter
import AVFoundation
import AudioToolbox
import GameController

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.kk.remote/platform"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiquidGlassTabBarPlugin") {
      registrar.register(
        LiquidTabBarFactory(messenger: registrar.messenger()),
        withId: "kk/liquid_tab_bar"
      )
    }

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      let args = call.arguments as? [String: Any]
      let feature = args?["feature"] as? String ?? ""
      switch feature {
      case "gamepad":
        result(true)
      case "pip", "cast", "recording", "foreground":
        // 画中画与投屏需要接入底层视频渲染层后启用，此处保留完整调用路径。
        result(false)
      default:
        result(false)
      }
    case "enterPictureInPicture", "startCast", "startScreenRecording":
      result(false)
    case "exitPictureInPicture", "stopCast", "stopScreenRecording":
      result(nil)
    case "listGamepads":
      let controllers = GCController.controllers()
      let list: [[String: Any]] = controllers.map { controller in
        let name = controller.vendorName ?? "MFi Controller"
        return [
          "id": controller.playerIndex.rawValue,
          "name": name,
          "descriptor": controller.productCategory,
          "type": "gamepad",
        ]
      }
      result(list)
    case "vibrate":
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      result(true)
    case "setKeepScreenOn":
      let args = call.arguments as? [String: Any]
      UIApplication.shared.isIdleTimerDisabled = args?["enabled"] as? Bool ?? false
      result(true)
    case "startForegroundService", "stopForegroundService":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
