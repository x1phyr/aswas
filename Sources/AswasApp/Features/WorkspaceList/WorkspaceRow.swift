import AswasCore
import Foundation
import SwiftUI

struct WorkspaceRow: View {
    let workspace: WorkspaceSnapshot
    let isOperating: Bool
    let restore: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
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
                    .foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(savedAtText(relativeTo: context.date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 12)
            Button(L10n.text("workspace.restore"), action: restore)
                .buttonStyle(.borderedProminent)
                .disabled(isOperating)
        }
        .padding(.vertical, 9)
    }

    private func savedAtText(relativeTo now: Date) -> String {
        guard abs(workspace.updatedAt.timeIntervalSince(now)) >= 60 else {
            return L10n.text("workspace.saved_just_now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeTime = formatter.localizedString(for: workspace.updatedAt, relativeTo: now)
        return L10n.text("workspace.saved_at", relativeTime)
    }
}
