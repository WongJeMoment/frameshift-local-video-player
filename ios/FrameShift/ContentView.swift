import SwiftUI
import UniformTypeIdentifiers

private let accent = Color(red: 201 / 255, green: 1, blue: 92 / 255)
private let pageBackground = Color(red: 16 / 255, green: 17 / 255, blue: 22 / 255)

struct ContentView: View {
    @StateObject private var model = PlayerStore()
    @State private var showingImporter = false
    @State private var fullScreen = false

    var body: some View {
        Group {
            if fullScreen {
                PlayerStage(model: model, fullScreen: $fullScreen) {
                    showingImporter = true
                }
                .ignoresSafeArea()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        VStack(spacing: 10) {
                            Text("YOUR VIDEO, YOUR PACE")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(accent)
                            Text("每一帧，按你的节奏。")
                                .font(.system(size: 38, weight: .bold))
                                .multilineTextAlignment(.center)
                            Text("从 iPad 选择本地视频，慢放看细节，快放抓重点。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 30)

                        PlayerStage(model: model, fullScreen: $fullScreen) {
                            showingImporter = true
                        }
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.18)))

                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(accent)
                            Text("视频只在这台 iPad 上读取，不会上传")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .font(.caption)
                        Spacer(minLength: 20)
                    }
                    .frame(maxWidth: 1100)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(pageBackground)
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.movie, .video],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.open(url) }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .alert("无法打开视频", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "请尝试其他视频格式。")
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "play.rectangle.on.rectangle")
                .foregroundStyle(accent)
            Text("FRAME/SHIFT")
                .fontWeight(.heavy)
                .tracking(1)
            Spacer()
            Text("本地播放 · 无需上传")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.headline)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
    }
}

private struct PlayerStage: View {
    @ObservedObject var model: PlayerStore
    @Binding var fullScreen: Bool
    var chooseVideo: () -> Void

    @State private var controlsVisible = false
    @State private var pointerAtBottom = false
    @State private var hideTask: Task<Void, Never>?
    @State private var showingSpeed = false
    @State private var scrubbing = false
    @State private var scrubTime: Double = 0
    @FocusState private var hasKeyboardFocus: Bool

    private let rates: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black

                if model.hasVideo {
                    PlayerSurface(player: model.player)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hasKeyboardFocus = true
                            model.togglePlayback()
                        }

                    if !model.isPlaying {
                        Button {
                            hasKeyboardFocus = true
                            model.togglePlayback()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .accessibilityLabel("播放视频")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if controlsVisible {
                        controls
                            .transition(.opacity)
                    } else {
                        Color.clear
                            .frame(height: min(160, geometry.size.height * 0.35))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { revealControls(forTouch: true) }
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 52, weight: .ultraLight))
                            .foregroundStyle(accent)
                        Text("选择本地视频")
                            .font(.title2.bold())
                        Text("在“文件”中选择视频，即可开始播放")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button(action: chooseVideo) {
                            Label("打开视频", systemImage: "square.and.arrow.up")
                                .fontWeight(.bold)
                                .padding(.horizontal, 19)
                                .padding(.vertical, 12)
                                .foregroundStyle(.black)
                                .background(accent, in: RoundedRectangle(cornerRadius: 9))
                        }
                        .padding(.top, 8)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 22 / 255, green: 25 / 255, blue: 26 / 255))
                }
            }
            .onContinuousHover { phase in
                guard model.hasVideo else { return }
                switch phase {
                case .active(let point):
                    if point.y >= geometry.size.height - min(170, geometry.size.height * 0.38) {
                        pointerAtBottom = true
                        revealControls()
                    } else {
                        pointerAtBottom = false
                        scheduleHide()
                    }
                case .ended:
                    pointerAtBottom = false
                    scheduleHide()
                }
            }
        }
        .focusable()
        .focused($hasKeyboardFocus)
        .onKeyPress(.leftArrow) {
            model.skip(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.skip(1)
            return .handled
        }
        .onKeyPress(.space) {
            model.togglePlayback()
            return .handled
        }
        .onChange(of: showingSpeed) { _, open in
            if !open { scheduleHide() }
        }
        .onDisappear { hideTask?.cancel() }
    }

    private var controls: some View {
        VStack(spacing: 11) {
            HStack(spacing: 12) {
                Text(formatTime(scrubbing ? scrubTime : model.currentTime))
                Slider(value: Binding(
                    get: { scrubbing ? scrubTime : model.currentTime },
                    set: { scrubTime = $0 }
                ), in: 0...max(model.duration, 1), onEditingChanged: { editing in
                    scrubbing = editing
                    if !editing { model.seek(to: scrubTime) }
                })
                .tint(accent)
                .accessibilityLabel("播放进度")
                Text(formatTime(model.duration))
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white.opacity(0.82))

            HStack(spacing: 18) {
                controlButton(model.isPlaying ? "pause.fill" : "play.fill",
                              label: model.isPlaying ? "暂停" : "播放") {
                    model.togglePlayback()
                }
                controlButton("gobackward.10", label: "后退 10 秒") { model.skip(-10) }
                controlButton("goforward.10", label: "快进 10 秒") { model.skip(10) }
                controlButton(model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                              label: model.isMuted ? "取消静音" : "静音") {
                    model.toggleMute()
                }
                Slider(value: $model.volume, in: 0...1)
                    .tint(accent)
                    .frame(width: 90)
                    .accessibilityLabel("音量")
                Spacer(minLength: 4)
                Button("\(model.playbackRate.formatted())×") {
                    showingSpeed = true
                }
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(accent)
                .popover(isPresented: $showingSpeed) { speedPicker }

                controlButton(fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                              label: fullScreen ? "退出全屏" : "全屏") {
                    fullScreen.toggle()
                }
                Button("更换视频", action: chooseVideo)
                    .font(.caption.bold())
                    .foregroundStyle(accent)
            }

            if let fileName = model.fileName {
                HStack {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text(fileName).lineLimit(1)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.86), .black.opacity(0.96)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var speedPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("播放速度").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(rates, id: \.self) { rate in
                    Button("\(rate.formatted())×") {
                        model.setRate(rate)
                        showingSpeed = false
                    }
                    .buttonStyle(.bordered)
                    .tint(rate == model.playbackRate ? accent : .gray)
                }
            }
            Text("精细调整：\(model.playbackRate.formatted(.number.precision(.fractionLength(2))))×")
                .font(.caption)
            Slider(value: Binding(
                get: { model.playbackRate },
                set: { model.setRate($0) }
            ), in: 0.25...4, step: 0.05)
            .tint(accent)
        }
        .padding(20)
        .frame(width: 340)
        .presentationCompactAdaptation(.popover)
    }

    private func controlButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }

    private func revealControls(forTouch: Bool = false) {
        hideTask?.cancel()
        hideTask = nil
        controlsVisible = true
        if !pointerAtBottom { scheduleHide(after: forTouch ? 3 : 0.3) }
    }

    private func scheduleHide(after seconds: Double = 0.3) {
        guard controlsVisible, !pointerAtBottom, !showingSpeed else { return }
        if hideTask != nil { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            hideTask = nil
            if !pointerAtBottom && !showingSpeed { controlsVisible = false }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = Int(max(0, seconds))
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%02d:%02d", minutes, remaining)
    }
}
