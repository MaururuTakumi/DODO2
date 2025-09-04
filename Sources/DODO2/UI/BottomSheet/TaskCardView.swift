import SwiftUI

struct TaskCardView: View {
    let task: Task
    let label: Label?
    let toggleDone: (Task) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill((label?.color.color ?? .accentColor))
                    .frame(width: 8, height: 8)
                Text(label?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
                ToggleDoneArea(done: task.done) { toggleDone(task) }
            }

            Text(task.title)
                .font(BrandTokens.titleFont)
                .foregroundColor(.primary)
                .strikethrough(task.done, color: .secondary)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.cornerRadius, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandTokens.cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.05))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onDrag {
            let payload = NSString(string: "task:\(task.id.uuidString)")
            return NSItemProvider(object: payload)
        }
        .accessibilityLabel(Text("Task \(task.title)"))
        .accessibilityHint(Text("Double tap to toggle done, drag to a label to assign"))
    }
}

private struct ToggleDoneArea: View {
    var done: Bool
    var action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(done ? .accentColor : .secondary)
            }
            .contentShape(Rectangle())
            .frame(width: 36, height: 28)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hover ? Color.secondary.opacity(0.12) : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(done ? "checked" : "unchecked"))
        .accessibilityLabel(Text("Done"))
    }
}
