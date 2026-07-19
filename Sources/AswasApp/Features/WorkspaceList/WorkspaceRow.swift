import AswasCore
import Foundation
import SwiftUI

struct WorkspaceRow: View {
    let workspace: WorkspaceSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(workspace.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(
                    L10n.text(
                        "workspace.summary",
                        workspace.finder.windows.count,
                        workspace.finder.tabCount
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                WorkspaceSavedTimeText(date: workspace.updatedAt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

struct WorkspaceSavedTimeText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(savedAtText(relativeTo: context.date))
        }
    }

    private func savedAtText(relativeTo now: Date) -> String {
        guard abs(date.timeIntervalSince(now)) >= 60 else {
            return L10n.text("workspace.saved_just_now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeTime = formatter.localizedString(for: date, relativeTo: now)
        return L10n.text("workspace.saved_at", relativeTime)
    }
}
