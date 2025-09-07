import SwiftUI
import UniformTypeIdentifiers

struct MatrixOverlayView: View {
    @Binding var items: [Task]
    var onClose: () -> Void = {}
    @State private var filter: MatrixFilter = .all
    @State private var targeted: Quadrant? = nil
    @State private var toast: HUDToastState? = nil
    @State private var highlightId: UUID? = nil

    var body: some View {
        VStack(spacing: 12) {
            header
            startHere
            content
        }
        .padding(16)
        .frame(maxWidth: 1240, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThickMaterial)
                .shadow(radius: 22)
        )
        .hudToast($toast)
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { onClose() }) {
                SwiftUI.Label("Back to Tasks", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Back to Tasks")

            Spacer()
            countChip("Do First", .doFirst)
            countChip("Schedule", .schedule)
            countChip("Delegate", .delegate)
            countChip("Eliminate", .eliminate)
            Picker("Filter", selection: $filter) {
                ForEach(MatrixFilter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            Spacer(minLength: 0)
            Button(action: { onClose() }) { Text("Close (Esc)") }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Close matrix")
        }
    }

    private func countChip(_ title: String, _ q: Quadrant) -> some View {
        let n = counts[q] ?? 0
        return Button(action: { filter = filter.quadrant == q ? .all : MatrixFilter(from: q) }) {
            Text("\(title): \(n)")
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((filter.quadrant == q ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        let spacing: CGFloat = 12
        let minCell: CGFloat = 220
        ScrollView(.vertical) {
            if let q = filter.quadrant {
                VStack(spacing: spacing) {
                    quadrantView(q, title: q.title, minHeight: minCell, weight: q == .doFirst ? 1.08 : 1.0)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 72)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 12) }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)],
                    spacing: spacing
                ) {
                    quadrantView(.doFirst,   title: "Do First",   minHeight: minCell, weight: 1.08)
                    quadrantView(.schedule,  title: "Schedule",   minHeight: minCell)
                    quadrantView(.delegate,  title: "Delegate",   minHeight: minCell)
                    quadrantView(.eliminate, title: "Eliminate",  minHeight: minCell)
                }
                .padding(.bottom, 72)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 12) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .contentMargins(.vertical, 4)
        #endif
        .scrollIndicators(.visible)
    }

    private func quadrantView(_ q: Quadrant, title: String, minHeight: CGFloat, weight: CGFloat = 1.0) -> AnyView {
        AnyView(QuadrantColumnView(
            items: items,
            q: q,
            title: title,
            minHeight: minHeight,
            weight: weight,
            targeted: Binding(get: { targeted }, set: { targeted = $0 }),
            highlightId: Binding(get: { highlightId }, set: { highlightId = $0 }),
            onDrop: { providers in handleDrop(into: q, providers: providers) }
        ))
    }

    private struct QuadrantColumnView: View {
        let items: [Task]
        let q: Quadrant
        let title: String
        let minHeight: CGFloat
        let weight: CGFloat
        @Binding var targeted: Quadrant?
        @Binding var highlightId: UUID?
        let onDrop: ([NSItemProvider]) -> Bool

        var body: some View {
            let st = q.style
            let filtered: [Task] = items.filter { $0.quadrant == q }
            let scored: [(Task, Int)] = filtered.map { ($0, doerScore($0)) }
            let ordered: [Task] = scored.sorted { $0.1 > $1.1 }.map { $0.0 }
            let rankMap: [UUID: Int] = Dictionary(uniqueKeysWithValues: ordered.prefix(3).enumerated().map { ($0.element.id, $0.offset + 1) })
            return VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: st.titleIcon).font(.subheadline)
                    Text(title).font(.headline)
                    Spacer()
                }
                VStack(spacing: 8) {
                    if ordered.isEmpty {
                        DashedDropHint(title: "Drop tasks here or toggle on cards")
                            .padding(.top, 8)
                    }
                    QuadrantRows(ordered: ordered, q: q, rankMap: rankMap, highlightId: $highlightId)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(minHeight: minHeight * weight)
            .background(st.tint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(targeted == q ? 0.8 : 0.0), style: StrokeStyle(lineWidth: 2, dash: [6,3]))
                    .animation(.easeInOut(duration: 0.2), value: targeted == q)
            )
            .overlay(alignment: .topLeading) {
                if targeted == q { Text("Drop to \(title)").font(.caption2).padding(6).background(.thinMaterial, in: Capsule())
                        .padding(8)
                        .transition(.opacity) }
            }
            .onDrop(of: [UTType.text], isTargeted: Binding(get: { targeted == q }, set: { v in targeted = v ? q : nil })) { providers in
                onDrop(providers)
            }
        }
    }

    private struct QuadrantRows: View {
        let ordered: [Task]
        let q: Quadrant
        let rankMap: [UUID: Int]
        @Binding var highlightId: UUID?
        var body: some View {
            ForEach(0..<ordered.count, id: \.self) { idx in
                let item = ordered[idx]
                HStack(spacing: 8) {
                    if q == .doFirst, let r = rankMap[item.id] { RankBadge(rank: r) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.subheadline).bold()
                        Text("I:\(item.importance)  U:\(item.urgency)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(q == .doFirst && idx < 3 ? Color.red.opacity(0.10 + 0.05 * Double(3 - idx)) : Color.gray.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(highlightId == item.id ? 0.9 : 0.0), lineWidth: 2)
                )
                .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
            }
        }
    }

    // D&D mapping
    @discardableResult
    private func handleDrop(into q: Quadrant, providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first,
              provider.canLoadObject(ofClass: NSString.self) else { return false }

        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let idStr = (obj as? NSString) as String?,
                  let uuid = UUID(uuidString: idStr),
                  let idx = items.firstIndex(where: { $0.id == uuid })
            else { return }

            let (i, u): (Int, Int) = {
                switch q {
                case .doFirst:   return (3,3)
                case .schedule:  return (3,1)
                case .delegate:  return (1,3)
                case .eliminate: return (1,1)
                }
            }()

            DispatchQueue.main.async {
                items[idx] = items[idx].updating(urgency: u, importance: i)
                showToast(for: items[idx])
            }
        }
        return true
    }

    private var counts: [Quadrant: Int] {
        Dictionary(grouping: items, by: \.quadrant).mapValues(\.count)
    }
    private func showToast(for task: Task) {
        let msg: String
        switch task.quadrant {
        case .doFirst: msg = "Moved to Do First"
        case .schedule: msg = "Moved to Schedule"
        case .delegate: msg = "Moved to Delegate"
        case .eliminate: msg = "Moved to Eliminate"
        }
        withAnimation { toast = HUDToastState(message: msg) }
    }
}

private enum MatrixFilter: String, CaseIterable, Identifiable {
    case all, doFirst, schedule, delegate, eliminate
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .doFirst: return "Do First"
        case .schedule: return "Schedule"
        case .delegate: return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }
    var quadrant: Quadrant? {
        switch self {
        case .all: return nil
        case .doFirst: return .doFirst
        case .schedule: return .schedule
        case .delegate: return .delegate
        case .eliminate: return .eliminate
        }
    }
}

private struct EmptyQuadrantHint: View {
    var title: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill").foregroundStyle(.secondary)
            Text("Drop tasks here or toggle on cards").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5,3]))
                .foregroundColor(.secondary.opacity(0.4))
        )
        .accessibilityHint(Text("Empty quadrant: \(title)"))
    }
}

private extension Quadrant {
    var title: String {
        switch self {
        case .doFirst: return "Do First"
        case .schedule: return "Schedule"
        case .delegate: return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }
    var style: QuadrantStyle {
        switch self {
        case .doFirst:   return QuadrantStyle(tint: Color.red.opacity(0.12),     titleIcon: "flame.fill")
        case .schedule:  return QuadrantStyle(tint: Color.blue.opacity(0.10),    titleIcon: "calendar")
        case .delegate:  return QuadrantStyle(tint: Color.purple.opacity(0.10),  titleIcon: "person.2")
        case .eliminate: return QuadrantStyle(tint: Color.gray.opacity(0.10),    titleIcon: "trash")
        }
    }
}

private extension MatrixFilter {
    init(from q: Quadrant) {
        switch q {
        case .doFirst: self = .doFirst
        case .schedule: self = .schedule
        case .delegate: self = .delegate
        case .eliminate: self = .eliminate
        }
    }
}

// MARK: - Styles & Helpers
private struct QuadrantStyle { let tint: Color; let titleIcon: String }

private func doerScore(_ t: Task) -> Int {
    let iu = t.importance * 2 + t.urgency
    let recency = max(0, 9 - Int(Date().timeIntervalSince(t.updatedAt) / 3600))
    return iu * 10 + recency
}

private struct RankBadge: View {
    let rank: Int
    var body: some View {
        Text("#\(rank)")
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.red.opacity(0.18))
            .clipShape(Capsule())
    }
}

private struct DashedDropHint: View {
    let title: String
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6,3]))
            .foregroundStyle(.secondary)
            .frame(height: 64)
            .overlay(
                SwiftUI.Label(title, systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
    }
}

// Start here strip (lives on the view via extension so it can access state)
private extension MatrixOverlayView {
    @ViewBuilder
    var startHere: some View {
        let top = items.filter { $0.quadrant == .doFirst }
            .sorted { doerScore($0) > doerScore($1) }
            .prefix(3)
        if !top.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 6) {
                            RankBadge(rank: idx+1)
                            Text(item.title).lineLimit(1)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.12)))
                        .onTapGesture {
                            highlightId = item.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { highlightId = nil }
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }
}
