import SwiftUI
import UIKit

// MARK: - 数据模型

struct LiquidTabItem: Identifiable, Equatable {
    let id: Int
    let symbol: String
    let title: String

    init(id: Int, symbol: String, title: String) {
        self.id = id
        self.symbol = symbol
        self.title = title
    }
}

/// 供 Flutter 与 SwiftUI 双向同步的选中状态。
final class LiquidTabBarModel: ObservableObject {
    @Published var selection: Int
    let items: [LiquidTabItem]
    var onSelect: ((Int) -> Void)?

    init(items: [LiquidTabItem], selection: Int) {
        self.items = items
        self.selection = selection
    }

    func select(_ index: Int) {
        guard index >= 0, index < items.count else { return }
        guard index != selection else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
            selection = index
        }
        onSelect?(index)
    }
}

// MARK: - 官方 Liquid Glass 标签栏（iOS 26+）

@available(iOS 26.0, *)
struct LiquidGlassTabBar: View {
    @ObservedObject var model: LiquidTabBarModel
    @Namespace private var glassNamespace
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(model.items) { item in
                    tabButton(item)
                        .glassEffect(
                            glassStyle(for: item),
                            in: Capsule()
                        )
                        .glassEffectID(item.id, in: glassNamespace)
                }
            }
            .padding(6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .animation(
            reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.76),
            value: model.selection
        )
    }

    // 选中项使用强调玻璃，其余使用普通玻璃；开启"降低透明度"时退化为实心胶囊。
    @ViewBuilder
    private func tabButton(_ item: LiquidTabItem) -> some View {
        let selected = model.selection == item.id
        Button {
            model.select(item.id)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.symbol)
                    .font(.system(size: 19, weight: selected ? .semibold : .regular))
                Text(item.title)
                    .font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.78))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func glassStyle(for item: LiquidTabItem) -> Glass {
        let selected = model.selection == item.id
        if selected {
            return .regular.tint(Color.accentColor.opacity(0.35)).interactive()
        }
        return .regular.interactive()
    }
}

// MARK: - 低版本 / 降低透明度时的回退样式

struct LiquidTabBarFallback: View {
    @ObservedObject var model: LiquidTabBarModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(model.items) { item in
                let selected = model.selection == item.id
                Button {
                    model.select(item.id)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 19, weight: selected ? .semibold : .regular))
                        Text(item.title)
                            .font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(
                            selected
                                ? Color.white.opacity(colorScheme == .dark ? 0.22 : 0.92)
                                : Color.clear
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

/// 宿主视图：按系统版本与辅助透明度设置选择官方玻璃或回退样式。
struct LiquidTabBarHost: View {
    @ObservedObject var model: LiquidTabBarModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            LiquidGlassTabBar(model: model)
        } else {
            LiquidTabBarFallback(model: model)
        }
    }
}
