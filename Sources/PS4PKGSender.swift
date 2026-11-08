import SwiftUI

// MARK: - App entry
@main
struct PS4PKGSenderApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// MARK: - Client (Remote Package Installer protocol, port 12800)
struct RPIClient {
    let host: String
    var port: Int = 12800

    struct InstallResponse: Decodable {
        let status: String?
        let task_id: Int?
        let error: String?
    }

    enum RPIError: LocalizedError {
        case badURL, server(String)
        var errorDescription: String? {
            switch self {
            case .badURL: return "عنوان IP غير صحيح"
            case .server(let m): return m
            }
        }
    }

    func install(packages: [String]) async throws -> String {
        guard let url = URL(string: "http://\(host):\(port)/api/install") else {
            throw RPIError.badURL
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["type": "direct", "packages": packages]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let res = try JSONDecoder().decode(InstallResponse.self, from: data)
        if res.status == "success" {
            return "تم الإرسال بنجاح ✅ (task: \(res.task_id ?? 0))"
        }
        throw RPIError.server(res.error ?? "فشل: \(String(data: data, encoding: .utf8) ?? "")")
    }
}

// MARK: - UI
struct ContentView: View {
    @AppStorage("ps4_ip") private var ip = ""
    @State private var links = ""
    @State private var status = ""
    @State private var sending = false

    var body: some View {
        NavigationView {
            Form {
                Section("IP الـ PS4") {
                    TextField("192.168.1.x", text: $ip)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                }
                Section("روابط PKG (رابط في كل سطر)") {
                    TextEditor(text: $links)
                        .frame(minHeight: 120)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section {
                    Button(sending ? "جاري الإرسال..." : "إرسال للتثبيت") { send() }
                        .disabled(sending || ip.isEmpty || links.isEmpty)
                    if !status.isEmpty { Text(status) }
                }
            }
            .navigationTitle("PS4 PKG Sender")
        }
    }

    private func send() {
        let list = links.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        sending = true
        status = ""
        Task {
            do {
                status = try await RPIClient(host: ip).install(packages: list)
            } catch {
                status = "خطأ: \(error.localizedDescription)"
            }
            sending = false
        }
    }
}

/*
 Info.plist — لازم تضيف هذي المفاتيح:

 <key>NSLocalNetworkUsageDescription</key>
 <string>للاتصال بجهاز PS4 على الشبكة المحلية</string>
 <key>NSAppTransportSecurity</key>
 <dict>
   <key>NSAllowsLocalNetworking</key><true/>
   <key>NSAllowsArbitraryLoads</key><true/>
 </dict>
*/
