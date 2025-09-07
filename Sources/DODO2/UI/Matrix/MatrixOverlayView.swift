import SwiftUI
import UniformTypeIdentifiers

struct MatrixOverlayView: View {
    @Binding var items: [Task]
    @Environment(\.dismiss) private var dismiss
    @State private var filter: MatrixFilter = .all

    var body: some View {
        VStack(spacing: 12) {
            header
            content
        }
        .padding()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Urgency × Importance").font(.title2).bold()
            Spacer()
            countChip("Do First", counts[.doFirst] ?? 0)
            countChip("Schedule", counts[.schedule] ?? 0)
            countChip("Delegate", counts[.delegate] ?? 0)
            countChip("Eliminate", counts[.eliminate] ?? 0)
            Picker("Filter", selection: $filter) {
                ForEach(MatrixFilter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            Button("Done") { dismiss() }
        }
    }

    private func countChip(_ title: String, _ n: Int) -> some View {
        Text("\(title): \(n)")
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    ForEach(items.filter { $0.quadrant == q }.sorted { $0.updatedAt > $1.updatedAt }) { item in
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
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
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
            }
        }
        return true
    }

    private var counts: [Quadrant: Int] {
        Dictionary(grouping: items, by: \.quadrant).mapValues(\.count)
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

