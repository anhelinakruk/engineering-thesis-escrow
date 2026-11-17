//
//  ReceiveView.swift
//  escrow
//
//  Sheet from the wallet home for topping up the wallet: the address as a QR
//  code and text, so another wallet (or a testnet faucet) can send ETH here.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveView: View {
    let address: EthAddress

    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let qr = Self.qrImage(address) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Text(address)
                    .font(.callout.monospaced())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = address
                    withAnimation { didCopy = true }
                } label: {
                    Label(didCopy ? "Copied" : "Copy address",
                          systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(Color.brandTeal)
                }

                Text("Send only ETH on the network this app is connected to.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
            .background(Color.appBackground)
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .tint(.brandTeal)
        }
    }

    private static func qrImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    ReceiveView(address: "0x20450f1FC62d218DDb2F5009262eF7258761a9b5")
        .preferredColorScheme(.dark)
}
