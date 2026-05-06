import SwiftUI
import SomeLens

struct SnapshotRefreshRateControl: View {
    @Binding private var refreshRate: SnapshotRefreshRate
    @Binding private var isInteractionBlocked: Bool
    private let safeInsets: EdgeInsets
    @State private var isPickerPresented = false
    @State private var isCustomEditorPresented = false
    @State private var customMillisecondsText = "200"

    init(
        refreshRate: Binding<SnapshotRefreshRate>,
        isInteractionBlocked: Binding<Bool> = .constant(false),
        safeInsets: EdgeInsets = EdgeInsets()
    ) {
        self._refreshRate = refreshRate
        self._isInteractionBlocked = isInteractionBlocked
        self.safeInsets = safeInsets
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            button
                .disabled(isCustomEditorPresented)

            if isPickerPresented {
                SnapshotRefreshRatePickerShade {
                    withAnimation {
                        isPickerPresented = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)

                SnapshotRefreshRatePicker(
                    selectedRate: $refreshRate,
                    onSelect: {
                        withAnimation {
                            isPickerPresented = false
                        }
                    },
                    onSelectCustom: {
                        customMillisecondsText = currentCustomMillisecondsText
                        withAnimation {
                            isPickerPresented = false
                            isCustomEditorPresented = true
                        }
                    }
                )
                .padding(.leading, safeInsets.leading + 12)
                .padding(.top, safeInsets.top + 54)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                .zIndex(2)
            }

            if isCustomEditorPresented {
                SnapshotRefreshRateCustomIntervalEditor(
                    millisecondsText: $customMillisecondsText,
                    onCommit: commitCustomRefreshRate
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: isPickerPresented)
        .animation(.easeInOut(duration: 0.2), value: isCustomEditorPresented)
        .onAppear {
            updateInteractionBlock()
        }
        .onChange(of: isPickerPresented) { _, _ in
            updateInteractionBlock()
        }
        .onChange(of: isCustomEditorPresented) { _, _ in
            updateInteractionBlock()
        }
    }

    private var button: some View {
        Button {
            withAnimation {
                isPickerPresented.toggle()
            }
        } label: {
            Text(refreshRate.displayTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.leading, safeInsets.leading + 12)
        .padding(.top, safeInsets.top + 12)
    }

    private var currentCustomMillisecondsText: String {
        if case .custom(let milliseconds) = refreshRate {
            "\(milliseconds)"
        } else {
            customMillisecondsText
        }
    }

    private func commitCustomRefreshRate(_ milliseconds: Int) {
        refreshRate = .custom(milliseconds: milliseconds)
        withAnimation {
            isCustomEditorPresented = false
        }
    }

    private func updateInteractionBlock() {
        isInteractionBlocked = isPickerPresented || isCustomEditorPresented
    }
}

struct SnapshotRefreshRatePickerShade: View {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    var body: some View {
        Color.black.opacity(0.18)
            .ignoresSafeArea()
            .onTapGesture(perform: onDismiss)
    }
}

struct SnapshotRefreshRatePicker: View {
    @Binding private var selectedRate: SnapshotRefreshRate
    private let onSelect: () -> Void
    private let onSelectCustom: () -> Void

    init(
        selectedRate: Binding<SnapshotRefreshRate>,
        onSelect: @escaping () -> Void,
        onSelectCustom: @escaping () -> Void
    ) {
        self._selectedRate = selectedRate
        self.onSelect = onSelect
        self.onSelectCustom = onSelectCustom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pickerButton(title: SnapshotRefreshRate.never.displayTitle, rate: .never)
            pickerButton(title: SnapshotRefreshRate.automatic.displayTitle, rate: .automatic)
            pickerButton(title: SnapshotRefreshRate.fast.displayTitle, rate: .fast)
            pickerButton(title: SnapshotRefreshRate.balanced.displayTitle, rate: .balanced)
            pickerButton(title: SnapshotRefreshRate.relaxed.displayTitle, rate: .relaxed)
            pickerButton(title: SnapshotRefreshRate.slow.displayTitle, rate: .slow)

            Button {
                onSelectCustom()
            } label: {
                Text("Custom")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(.primary)
        .frame(width: 160)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }

    private func pickerButton(title: String, rate: SnapshotRefreshRate) -> some View {
        Button {
            selectedRate = rate
            onSelect()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

struct SnapshotRefreshRateCustomIntervalEditor: View {
    @Binding private var millisecondsText: String
    private let onCommit: (Int) -> Void

    init(millisecondsText: Binding<String>, onCommit: @escaping (Int) -> Void) {
        self._millisecondsText = millisecondsText
        self.onCommit = onCommit
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Custom milliseconds")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                TextField("Milliseconds", text: $millisecondsText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 180)
                    .numberOnlyKeyboard()
                    .onChange(of: millisecondsText) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue {
                            millisecondsText = digits
                        }
                    }

                Button("OK") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(millisecondsText.isEmpty)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
    }

    private func commit() {
        guard let milliseconds = Int(millisecondsText), milliseconds > 0 else { return }
        onCommit(milliseconds)
    }
}

extension SnapshotRefreshRate {
    var displayTitle: String {
        switch self {
        case .never:
            "Never"
        case .automatic:
            "Automatic"
        case .fast:
            "Fast"
        case .balanced:
            "Balanced"
        case .relaxed:
            "Relaxed"
        case .slow:
            "Slow"
        case .custom(let milliseconds):
            "\(milliseconds) ms"
        }
    }
}

private extension View {
    @ViewBuilder
    func numberOnlyKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
