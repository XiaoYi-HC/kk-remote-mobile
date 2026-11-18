import Flutter
import SwiftUI
import UIKit

/// Flutter 平台视图：把官方 SwiftUI Liquid Glass 标签栏嵌进 Flutter 页面。
final class LiquidTabBarPlatformView: NSObject, FlutterPlatformView {
    private let hostController: UIViewController
    private let channel: FlutterMethodChannel
    private let model: LiquidTabBarModel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        let params = args as? [String: Any] ?? [:]
        let rawItems = params["items"] as? [[String: Any]] ?? []
        let items = rawItems.enumerated().map { index, raw in
            LiquidTabItem(
                id: index,
                symbol: raw["symbol"] as? String ?? "circle",
                title: raw["title"] as? String ?? ""
            )
        }
        let initialIndex = params["index"] as? Int ?? 0
        model = LiquidTabBarModel(items: items, selection: initialIndex)
        channel = FlutterMethodChannel(
            name: "kk/liquid_tab_bar/\(viewId)",
            binaryMessenger: messenger
        )

        let host = UIHostingController(rootView: LiquidTabBarHost(model: model))
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        hostController = host

        super.init()

        model.onSelect = { [weak channel] index in
            channel?.invokeMethod("select", arguments: index)
        }

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            switch call.method {
            case "setSelection":
                if let index = call.arguments as? Int {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                        self.model.selection = index
                    }
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView {
        hostController.view
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }
}

final class LiquidTabBarFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> (NSObjectProtocol & FlutterMessageCodec) {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        LiquidTabBarPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }
}
