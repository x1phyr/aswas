import AswasCore
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
                Text(workspace.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 12)
            Button(L10n.text("workspace.restore"), action: restore)
                .buttonStyle(.borderedProminent)
                .disabled(isOperating)
        }
        .padding(.vertical, 9)
    }
}
