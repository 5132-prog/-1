import SwiftUI
import Translation

struct ContentView: View {
    @State private var model = InterpreterModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            transcriptList
            footer
        }
        .background(Color(.systemGroupedBackground))
        .translationTask(model.translationConfig) { session in
            await model.handleSession(session)
        }
        .task { model.prepare() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("俄语 → 汉语 实时同传")
                .font(.headline)
            Text(model.statusText.isEmpty ? "点击下方按钮开始，对着手机说俄语" : model.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if model.entries.isEmpty && model.partialRussian.isEmpty {
                    emptyState
                }
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(model.entries) { entry in
                        EntryView(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: model.entries.count) { _, _ in
                if let last = model.entries.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("俄语原句和中文译文会显示在这里")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if !model.partialRussian.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("识别中", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.partialRussian)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            HStack(spacing: 28) {
                Button {
                    model.clearTranscript()
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(model.entries.isEmpty)

                Button {
                    model.toggleListening()
                } label: {
                    Image(systemName: model.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 30))
                        .frame(width: 76, height: 76)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isListening ? .gray : .red)
            }
            .padding(.bottom, 24)
        }
    }
}

struct EntryView: View {
    let entry: InterpreterModel.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.russian)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let chinese = entry.chinese {
                Text(chinese)
                    .font(.title3.weight(.semibold))
            } else if entry.failed {
                Label("翻译失败", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("翻译中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
