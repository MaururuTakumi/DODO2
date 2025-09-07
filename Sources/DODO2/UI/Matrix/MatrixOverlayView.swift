import SwiftUI
import UniformTypeIdentifiers

struct MatrixOverlayView: View {
    @Binding var items: [Task]
    var onClose: () -> Void = {}
    @State private var filter: MatrixFilter = .all
    @State private var targeted: Quadrant? = nil
    @State private var toast: HUDToastState? = nil

    var body: some View {
        VStack(spacing: 12) {
            header
            content
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 560)
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
        if let q = filter.quadrant {
            quadrant(q, title: q.title)
        } else {
            let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: cols, spacing: 12) {
                quadrant(.doFirst,   title: "Do First")
                quadrant(.schedule,  title: "Schedule")
                quadrant(.delegate,  title: "Delegate")
                quadrant(.eliminate, title: "Eliminate")
            }
        }
    }

    @ViewBuilder
    private func quadrant(_ q: Quadrant, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ScrollView {
                VStack(spacing: 8) {
                    let data = items.filter { $0.quadrant == q }.sorted { $0.updatedAt > $1.updatedAt }
                    if data.isEmpty {
                        EmptyQuadrantHint(title: title)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                    ForEach(data) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline).bold()
                            Text("I:\(item.importance)  U:\(item.urgency)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(targeted == q ? 0.8 : 0.0), style: StrokeStyle(lineWidth: 2, dash: targeted == q ? [] : []))
                .animation(.easeInOut(duration: 0.2), value: targeted == q)
        )
        .overlay(alignment: .topTrailing) {
            if targeted == q { Text("Drop to \(title)").font(.caption).padding(6).background(.thinMaterial, in: Capsule())
                    .transition(.opacity) }
        }
        .onDrop(of: [UTType.text], isTargeted: Binding(get: { targeted == q }, set: { v in targeted = v ? q : nil })) { providers in
            handleDrop(into: q, providers: providers)
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
