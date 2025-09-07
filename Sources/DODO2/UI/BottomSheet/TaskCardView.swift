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
    @Environment(\.cardMetrics) private var M

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(badgeColor).frame(width: 8, height: 8)
                Text(label?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
                if let onToggleImportant {
                    PillToggle(icon: "star.fill", label: "Important", active: task.importance >= 2) { onToggleImportant(task) }
                }
                if let onToggleUrgent {
                    PillToggle(icon: "bolt.fill", label: "Urgent", active: task.urgency >= 2) { onToggleUrgent(task) }
                }
                MatrixMiniBadge(quadrant: task.quadrant)
                ToggleDoneArea(done: task.done) { toggleDone(task) }
            }
            .controlSize(M.controlSize)

            Text(task.title)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.primary)
                .strikethrough(task.done, color: .secondary)

            Text("I:\(task.importance)  U:\(task.urgency)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, M.vPad)
        .padding(.horizontal, M.hPad)
        .frame(height: M.height, alignment: .topLeading)
        .frame(minWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: M.corner, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: M.corner, style: .continuous)
                .stroke(Color.black.opacity(0.05))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: M.corner, style: .continuous))
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
// Old CardContainer replaced by metrics-based rendering

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

// Compact pill toggle
private struct PillToggle: View {
    let icon: String
    let label: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label).lineLimit(1).fixedSize()
            }
            .font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background((active ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12)))
        .overlay(Capsule().stroke(active ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: 1))
        .clipShape(Capsule())
        .help(label)
        .accessibilityLabel(Text(label))
        .accessibilityHint(Text("Toggle \(label)"))
    }
}

// Mini quadrant badge
private struct MatrixMiniBadge: View {
    let quadrant: Quadrant
    @State private var glow: Bool = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(glow ? 0.8 : 0.0), lineWidth: glow ? 2 : 0)
                        .animation(.easeInOut(duration: 0.8), value: glow)
                )
            GridMarker(active: quadrant)
        }
        .frame(width: 28, height: 20)
        .onChange(of: quadrant) { _ in
            glow = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { glow = false }
        }
        .accessibilityHidden(true)
    }
}

private struct GridMarker: View {
    let active: Quadrant
    private func cellColor(_ q: Quadrant) -> Color { q == active ? .accentColor : .secondary.opacity(0.35) }
    var body: some View {
        HStack(spacing: 3) {
            VStack(spacing: 3) {
                Circle().fill(cellColor(.doFirst)).frame(width: 4, height: 4)
                Circle().fill(cellColor(.delegate)).frame(width: 4, height: 4)
            }
            VStack(spacing: 3) {
                Circle().fill(cellColor(.schedule)).frame(width: 4, height: 4)
                Circle().fill(cellColor(.eliminate)).frame(width: 4, height: 4)
            }
        }
    }
}
