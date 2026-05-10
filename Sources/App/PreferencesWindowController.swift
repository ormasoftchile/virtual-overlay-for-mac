import AppKit
import OverlayRenderer
import Persistence
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: WatermarkPreferencesViewModel

    init(appearance: WatermarkAppearance) {
        self.viewModel = WatermarkPreferencesViewModel(appearance: appearance)
        let contentView = PreferencesView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Virtual Overlay — Preferences"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPreferences() {
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct PreferencesView: View {
    @ObservedObject private var viewModel: WatermarkPreferencesViewModel
    @State private var draft: WatermarkPreferences

    init(viewModel: WatermarkPreferencesViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.appearance.preferences)
    }

    var body: some View {
        Form {
            Section("Color") {
                VStack(alignment: .leading, spacing: 12) {
                    ColorPicker(
                        "Watermark text color",
                        selection: Binding(
                            get: { draft.color.swiftUIColor },
                            set: { draft = draft.replacing(color: CodableColor(swiftUIColor: $0)) }
                        ),
                        supportsOpacity: false
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(viewModel.swatches) { swatch in
                            Button {
                                draft = draft.replacing(color: swatch.color)
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(swatch.color.swiftUIColor)
                                        .frame(width: 16, height: 16)
                                    Text(swatch.name)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }

            Section("Opacity") {
                HStack {
                    Slider(
                        value: $draft.opacity,
                        in: 0.01...1.0,
                        step: 0.01
                    )
                    Text("Opacity: \(Int((draft.opacity * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 110, alignment: .trailing)
                }
            }

            Section("Font") {
                Picker("Family", selection: Binding(
                    get: { draft.fontFamily },
                    set: { draft = draft.replacing(fontFamily: $0) }
                )) {
                    ForEach(WatermarkFontFamily.allCases) { family in
                        Text(family.displayName).tag(family)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(draft.fontSize) },
                            set: { draft = draft.replacing(fontSize: CGFloat($0)) }
                        ),
                        in: 80...400,
                        step: 1
                    )
                    Text("\(Int(draft.fontSize.rounded())) pt")
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)
                }
            }

            Section("Placement") {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        placementButton(.upperLeft)
                        placementButton(.upperRight)
                    }
                    GridRow {
                        placementButton(.lowerLeft)
                        placementButton(.lowerRight)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 480)
        .onChange(of: draft) { newDraft in
            draft = viewModel.apply(newDraft)
        }
    }

    private func placementButton(_ position: WatermarkPosition) -> some View {
        Button {
            draft = draft.replacing(position: position)
        } label: {
            HStack {
                Image(systemName: draft.position == position ? "largecircle.fill.circle" : "circle")
                Text(position.displayName)
                Spacer()
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
    }
}
