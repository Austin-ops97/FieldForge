import SwiftUI
import UIKit

struct PDFShareButton: View {
    @Binding var fileURL: URL?
    @Binding var failed: Bool
    var accessibilityLabel: String
    var makeFile: @MainActor () -> URL?

    var body: some View {
        Button {
            if let fileURL = makeFile() {
                self.fileURL = fileURL
            } else {
                failed = true
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

extension View {
    /// Presents the system share sheet for a PDF written on this iPhone.
    func pdfShareSheet(url: Binding<URL?>, failed: Binding<Bool>) -> some View {
        fileShareSheet(
            url: url,
            failed: failed,
            failureTitle: "Couldn't create the PDF",
            failureMessage: "The quote or invoice is still on this iPhone. Try sharing again."
        )
    }

    func fileShareSheet(
        url: Binding<URL?>,
        failed: Binding<Bool>,
        failureTitle: String,
        failureMessage: String
    ) -> some View {
        sheet(
            isPresented: Binding(
                get: { url.wrappedValue != nil },
                set: { if $0 == false { url.wrappedValue = nil } }
            )
        ) {
            if let fileURL = url.wrappedValue {
                PDFActivityView(url: fileURL)
                    .ignoresSafeArea()
            }
        }
        .alert(failureTitle, isPresented: failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failureMessage)
        }
    }
}

private struct PDFActivityView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ShareHostController {
        let host = ShareHostController()
        host.fileURL = url
        host.onFinish = { dismiss() }
        return host
    }

    func updateUIViewController(_ controller: ShareHostController, context: Context) {
        controller.fileURL = url
    }
}

private final class ShareHostController: UIViewController {
    var fileURL: URL?
    var onFinish: () -> Void = {}
    private var didPresent = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard didPresent == false, let fileURL else { return }
        didPresent = true
        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 1,
            height: 1
        )
        activity.popoverPresentationController?.permittedArrowDirections = []
        activity.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.onFinish()
        }
        present(activity, animated: true)
    }
}
