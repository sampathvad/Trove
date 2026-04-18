import SwiftUI
import AppKit

struct PanelView: View {
    @StateObject private var store = ClipStore.shared
    @State private var searchText = ""
    @State private var selectedId: UUID?
    @State private var activeFilter: FilterChip = .all
    @State private var searchResults: [Clip] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var showDetailFor: Clip?
    @State private var undoToastClip: Clip?
    @State private var toastTask: Task<Void, Never>?
    @State private var multiPasteSeparator = "\n"
    @FocusState private var searchFocused: Bool

    var displayedClips: [Clip] {
        let base = searchText.isEmpty ? store.clips : searchResults
        guard activeFilter != .all else { return base }
        return base.filter { $0.type.filterChip == activeFilter }
    }

    var pinnedClips: [Clip] { displayedClips.filter { $0.isPinned } }
    var unpinnedClips: [Clip] { displayedClips.filter { !$0.isPinned } }
    var selectedClip: Clip? { selectedId.flatMap { id in displayedClips.first { $0.id == id } } }

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    searchBar
                    filterChips
                    Divider()
                    clipList
                    if selectedIds.count > 1 { multiPasteBar }
                }
                if let clip = showDetailFor {
                    Divider()
                    DetailPreviewView(clip: clip) { showDetailFor = nil }
                        .frame(width: 280)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .background(.regularMaterial)

            if let clip = undoToastClip { undoToast(for: clip).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.easeInOut(duration: 0.18), value: showDetailFor?.id)
        .animation(.easeInOut(duration: 0.18), value: undoToastClip?.id)
        .onKeyPress(keys: [.escape]) { _ in handleEscape() }
        .onKeyPress(keys: [.upArrow]) { _ in moveSelection(by: -1) }
        .onKeyPress(keys: [.downArrow]) { _ in moveSelection(by: 1) }
        .onKeyPress(keys: [.return]) { _ in pasteSelected(); return .handled }
        .onKeyPress(keys: [.space]) { _ in toggleDetail(); return .handled }
        .onKeyPress(.init("p"), phases: .down) { e in guard e.modifiers == .command else { return .ignored }; pinSelected(); return .handled }
        .onKeyPress(.delete, phases: .down) { e in guard e.modifiers == .command else { return .ignored }; deleteSelected(); return .handled }
        .onKeyPress(.init("z"), phases: .down) { e in guard e.modifiers == .command else { return .ignored }; undoDelete(); return .handled }
        .onKeyPress(.init("k"), phases: .down) { e in guard e.modifiers == .command else { return .ignored }; searchFocused = true; return .handled }
        .onKeyPress(phases: .down) { e in
            guard e.modifiers == .command,
                  let n = e.key.character.wholeNumberValue,
                  n >= 1 && n <= 9 else { return .ignored }
            let idx = n - 1
            guard idx < displayedClips.count else { return .handled }
            PanelController.shared.closeAndPaste(displayedClips[idx])
            return .handled
        }
        .onAppear { searchFocused = true; if selectedId == nil { selectedId = displayedClips.first?.id } }
        .onChange(of: displayedClips.count) { _, _ in
            if selectedId == nil || !displayedClips.contains(where: { $0.id == selectedId }) { selectedId = displayedClips.first?.id }
        }
    }


    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clips…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onAppear { searchFocused = true }
                .onChange(of: searchText) { _, q in Task { searchResults = await ClipStore.shared.search(q) } }
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FilterChip.allCases, id: \.self) { chip in
                    FilterChipButton(chip: chip, isActive: activeFilter == chip) {
                        activeFilter = chip; selectedId = displayedClips.first?.id
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if !pinnedClips.isEmpty {
                        Section { ForEach(pinnedClips) { clipRow($0) } } header: { sectionHeader("Pinned") }
                    }
                    Section {
                        ForEach(unpinnedClips) { clipRow($0) }
                    } header: { if !pinnedClips.isEmpty { sectionHeader("Recent") } }
                }
            }
            .onChange(of: selectedId) { _, id in if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } } }
        }
    }

    private func clipRow(_ clip: Clip) -> some View {
        ClipRow(clip: clip, index: displayedClips.firstIndex(of: clip).map { $0 + 1 },
                isSelected: selectedId == clip.id, isMultiSelected: selectedIds.contains(clip.id), searchText: searchText)
        .id(clip.id)
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                if selectedIds.contains(clip.id) { selectedIds.remove(clip.id) } else { selectedIds.insert(clip.id) }
            } else { selectedIds.removeAll(); selectedId = clip.id }
        }
        .gesture(TapGesture(count: 2).onEnded { PanelController.shared.closeAndPaste(clip) })
    }

    private var multiPasteBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedIds.count) selected").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $multiPasteSeparator) {
                Text("Newline").tag("\n"); Text("Tab").tag("\t"); Text("Comma").tag(", "); Text("Space").tag(" ")
            }
            .labelsHidden().pickerStyle(.menu).frame(width: 90)
            Button("Paste all") { pasteMultiple() }.buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 8).background(.regularMaterial)
    }

    private func undoToast(for clip: Clip) -> some View {
        HStack(spacing: 12) {
            Text("Clip deleted").font(.callout)
            Button("Undo") { undoDelete() }.buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule()).shadow(radius: 4).padding(.bottom, 12)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 4).background(.regularMaterial)
    }

    @discardableResult
    private func handleEscape() -> KeyPress.Result {
        if showDetailFor != nil { showDetailFor = nil; return .handled }
        if !searchText.isEmpty { searchText = ""; return .handled }
        PanelController.shared.close(); return .handled
    }

    @discardableResult
    private func moveSelection(by delta: Int) -> KeyPress.Result {
        guard !displayedClips.isEmpty else { return .handled }
        let cur = displayedClips.firstIndex(where: { $0.id == selectedId }) ?? -1
        selectedId = displayedClips[max(0, min(displayedClips.count - 1, cur + delta))].id
        return .handled
    }

    private func pasteSelected() { if let c = selectedClip { PanelController.shared.closeAndPaste(c) } }

    private func pasteMultiple() {
        let ordered = displayedClips.filter { selectedIds.contains($0.id) }
        let joined = ordered.compactMap { $0.content.previewText }.joined(separator: multiPasteSeparator)
        PanelController.shared.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(joined, forType: .string)
            PasteService.simulatePaste()
        }
    }

    private func toggleDetail() { if let c = selectedClip { showDetailFor = showDetailFor?.id == c.id ? nil : c } }
    private func pinSelected() { if let c = selectedClip { Task { await ClipStore.shared.togglePin(c) } } }

    private func deleteSelected() {
        guard let clip = selectedClip else { return }
        _ = store.softDelete(clip)
        undoToastClip = clip
        toastTask?.cancel()
        toastTask = Task { try? await Task.sleep(for: .seconds(5)); guard !Task.isCancelled else { return }; undoToastClip = nil }
    }

    private func undoDelete() { store.undoDelete(); undoToastClip = nil; toastTask?.cancel() }
}

struct FilterChipButton: View {
    let chip: FilterChip; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(chip.displayName).font(.caption).fontWeight(isActive ? .semibold : .regular)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
