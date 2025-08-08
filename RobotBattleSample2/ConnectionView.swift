import SwiftUI

struct ConnectionView: View {
    @State private var isConnected = false
    @State private var isCentral: Bool? = nil
    @State private var delegateHolder: ConnectionDelegate?

    var body: some View {
        VStack(spacing: 40) {
            Text("BattleBot 接続")
                .font(.largeTitle)
                .bold()

            if let role = isCentral {
                Text(role ? "左端末（Central）として接続中" : "右端末（Peripheral）として待機中")
                    .foregroundColor(.gray)

                if isConnected {
                    NavigationLink("対戦開始", destination: BattleView(isCentral: role))
                } else {
                    ProgressView()
                }
            } else {
                Text("どちらの端末として動作しますか？")

                Button("左端末として接続（Central）") {
                    isCentral = true
                    BluetoothManager.shared.startAsCentral()
                    let delegate = ConnectionDelegate {
                        isConnected = true
                    }
                    BluetoothManager.shared.delegate = delegate
                    delegateHolder = delegate // ← 保持！
                }
                .buttonStyle(.borderedProminent)

                Button("右端末として待機（Peripheral）") {
                    isCentral = false
                    BluetoothManager.shared.startAsPeripheral()
                    let delegate = ConnectionDelegate {
                        isConnected = true
                    }
                    BluetoothManager.shared.delegate = delegate
                    delegateHolder = delegate // ← 保持！
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// デリゲートは NSObject 継承が必要（BluetoothManagerDelegate が Objective-C プロトコル）
class ConnectionDelegate: NSObject, BluetoothManagerDelegate {
    let onConnect: () -> Void

    init(onConnect: @escaping () -> Void) {
        self.onConnect = onConnect
    }

    func didConnectToPeer() {
        print("[Delegate] Connected to peer ✅")
        onConnect()
    }

    func didReceiveMessage(_ message: BluetoothMessage) {}
    func didDisconnect() {}
}
