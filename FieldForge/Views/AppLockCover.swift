import SwiftUI

struct AppLockCover: View {
    @Environment(AppLock.self) private var appLock

    var body: some View {
        VStack(spacing: ForgeTheme.Space.m) {
            Spacer()
            Image("LaunchMark")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            Text("FieldForge")
                .font(ForgeType.section)
                .foregroundStyle(.white)
            Text("Locked on this iPhone")
                .font(ForgeType.secondary)
                .foregroundStyle(.white.opacity(0.72))
            Button {
                Task { await appLock.unlock() }
            } label: {
                Text("Unlock")
                    .font(ForgeType.rowTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 240, minHeight: 48)
                    .background(ForgeTheme.copper, in: RoundedRectangle(cornerRadius: ForgeTheme.Radius.m, style: .continuous))
            }
            .accessibilityLabel("Unlock")
            .padding(.top, ForgeTheme.Space.xs)
            if let failure = appLock.failureMessage {
                Text(failure)
                    .font(ForgeType.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ForgeTheme.Space.l)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForgeTheme.ink)
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .task {
            await appLock.unlock()
        }
    }
}
