import SwiftUI
import AppKit

struct TaskCardView: View {
    let task: Task
    let label: Label?
    let toggleDone: (Task) -> Void
    var onRequestDelete: (() -> Void)? = nil
    var onToggleImportant: ((Task) -> Void)? = nil
    var onToggleUrgent: ((Task) -> Void)? = nil

    private var badgeColor: Color { label?.color.color ?? .accentColor }

    var body: some View {
        CardContainer {
            // header (label dot + name + done toggle)
            HStack(spacing: 8) {
                Circle().fill(badgeColor).frame(width: 8, height: 8)
                Text(label?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
                // Priority pills
                if let onToggleImportant {
                    PillButton(active: task.importance >= 2, label: "Important", systemImage: "star.fill") { onToggleImportant(task) }
                }
                if let onToggleUrgent {
                    PillButton(active: task.urgency >= 2, label: "Urgent", systemImage: "bolt.fill") { onToggleUrgent(task) }
                }
                ToggleDoneArea(done: task.done) { toggleDone(task) }
            }

            // title
            Text(task.title)
                .font(BrandTokens.titleFont)
                .foregroundColor(.primary)
                .strikethrough(task.done, color: .secondary)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
        .onDrag { NSItemProvider(object: NSString(string: "task:\(task.id.uuidString)")) }
        .contextMenu {
            Button(role: .destructive) { onRequestDelete?() } label: {
                SwiftUI.Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(Text("Task \(task.title)"))
        .accessibilityHint(Text("Double tap to toggle done, drag to a label to assign"))
    }
}

// 背景・枠線・影を担当（型を単純に保つ）
private struct CardContainer<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let r = BrandTokens.cornerRadius
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(Color.black.opacity(0.05))
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            .contentShape(Rectangle()) // 単純な型でヒット判定
    }
}

private struct ToggleDoneArea: View {
    var done: Bool
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .imageScale(.large)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .opacity(hover ? 0.9 : 1.0)
        .accessibilityLabel(done ? "Mark as not done" : "Mark as done")
    }
}

// Reusable pill button
private struct PillButton: View {
    var active: Bool
    var label: String
    var systemImage: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            SwiftUI.Label(label, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background((active ? Color.accentColor.opacity(0.20) : Color.gray.opacity(0.15)))
        .overlay(Capsule().stroke(active ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: 1))
        .clipShape(Capsule())
        .help(label)
    }
}
