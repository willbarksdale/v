import UIKit
import Flutter
import SwiftUI

// ============================================================================
// NATIVE SSH LOGIN SCREEN - Liquid Glass iOS Design
// ============================================================================

// MARK: - Custom TextField Wrapper

struct LiquidGlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)? = nil
    var trailingButton: (() -> AnyView)? = nil
    
    var body: some View {
        ZStack(alignment: .trailing) {
            if isSecure {
                SecureField("", text: $text)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black))
                    )
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            } else {
                TextField("", text: $text)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black))
                    )
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
            }
            
            if let trailingButton = trailingButton {
                trailingButton()
                    .padding(.trailing, 12)
            }
        }
    }
}

// MARK: - View Model

class SSHLoginViewModel: ObservableObject {
    @Published var serverIP: String = ""
    @Published var port: String = "22"
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var privateKey: String = ""
    @Published var privateKeyPassphrase: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRotating: Bool = false
    
    var onConnect: ((String, String, String, String, String, String) -> Void)?
    var onLoadCredentials: (() -> Void)?
    
    func connect() {
        guard !serverIP.isEmpty, !port.isEmpty, !username.isEmpty else { return }
        guard !password.isEmpty || !privateKey.isEmpty else { return }
        isLoading = true
        onConnect?(serverIP, port, username, password, privateKey, privateKeyPassphrase)
    }
    
    func loadRecentCredentials() {
        isRotating = true
        onLoadCredentials?()
    }
    
    func stopRotation() {
        isRotating = false
    }
    
    func stopLoading() {
        isLoading = false
    }
}

// MARK: - SwiftUI View

struct NativeSSHLoginScreen: View {
    @ObservedObject var viewModel: SSHLoginViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case serverIP, port, username, password, privateKey, privateKeyPassphrase
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04) // #0a0a0a
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Top padding for Power button and status bar
                    Spacer().frame(height: 100)
                    
                    // Title
                    Text("Create the future.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 3)
                        .padding(.bottom, 24)
                    
                    // Server IP and Port Row
                    HStack(spacing: 16) {
                        // Server IP Field (70% width)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server IP")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            
                            LiquidGlassTextField(
                                placeholder: "",
                                text: $viewModel.serverIP,
                                textContentType: .URL,
                                submitLabel: .next,
                                onSubmit: { focusedField = .port },
                                trailingButton: {
                                    AnyView(
                                        Button(action: {
                                            viewModel.loadRecentCredentials()
                                        }) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                                .rotationEffect(.degrees(viewModel.isRotating ? 360 : 0))
                                                .animation(viewModel.isRotating ? .linear(duration: 0.5).repeatForever(autoreverses: false) : .default, value: viewModel.isRotating)
                                        }
                                    )
                                }
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Port Field (30% width)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Port")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            
                            LiquidGlassTextField(
                                placeholder: "",
                                text: $viewModel.port,
                                keyboardType: .numberPad,
                                submitLabel: .next,
                                onSubmit: { focusedField = .username }
                            )
                        }
                        .frame(width: 100)
                    }
                    
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        LiquidGlassTextField(
                            placeholder: "",
                            text: $viewModel.username,
                            textContentType: .username,
                            submitLabel: .next,
                            onSubmit: { focusedField = .password }
                        )
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        LiquidGlassTextField(
                            placeholder: "",
                            text: $viewModel.password,
                            isSecure: !viewModel.isPasswordVisible,
                            textContentType: .password,
                            submitLabel: .next,
                            onSubmit: { focusedField = .privateKey },
                            trailingButton: {
                                AnyView(
                                    Button(action: {
                                        viewModel.isPasswordVisible.toggle()
                                    }) {
                                        Image(systemName: "eye")
                                            .font(.system(size: 20))
                                            .foregroundColor(viewModel.isPasswordVisible ? .white : .white.opacity(0.7))
                                    }
                                )
                            }
                        )
                    }
                    
                    // Private Key Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Private Key (optional)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        LiquidGlassTextField(
                            placeholder: "",
                            text: $viewModel.privateKey,
                            submitLabel: .next,
                            onSubmit: { focusedField = .privateKeyPassphrase }
                        )
                    }
                    
                    // Private Key Passphrase Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Private Key Passphrase (optional)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        LiquidGlassTextField(
                            placeholder: "",
                            text: $viewModel.privateKeyPassphrase,
                            isSecure: !viewModel.isPasswordVisible,
                            submitLabel: .done,
                            onSubmit: {
                                focusedField = nil
                                viewModel.connect()
                            }
                        )
                    }
                    
                    // Bottom padding
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Flutter Plugin

class NativeSSHScreenPlugin: NSObject, FlutterPlugin {
    private var viewModel: SSHLoginViewModel?
    private var hostingController: UIHostingController<NativeSSHLoginScreen>?
    private var methodChannel: FlutterMethodChannel?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "native_ssh_screen", binaryMessenger: registrar.messenger())
        let instance = NativeSSHScreenPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showNativeSSHScreen":
            showNativeSSHScreen(result: result)
        case "hideNativeSSHScreen":
            hideNativeSSHScreen(result: result)
        case "loadCredentials":
            loadCredentials(call: call, result: result)
        case "stopLoading":
            stopLoading(result: result)
        case "showConnectionError":
            showConnectionError(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func showNativeSSHScreen(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(false)
                return
            }
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let flutterViewController = window.rootViewController as? FlutterViewController else {
                result(false)
                return
            }
            
            // Show Power Button (Top Right)
            let powerButtonChannel = FlutterMethodChannel(name: "liquid_glass_power_button", binaryMessenger: flutterViewController.binaryMessenger)
            powerButtonChannel.invokeMethod("enableNativeLiquidGlassPowerButton", arguments: ["isConnected": false])
            
            // Show Info Button (Top Left)
            let infoButtonChannel = FlutterMethodChannel(name: "liquid_glass_info_button", binaryMessenger: flutterViewController.binaryMessenger)
            infoButtonChannel.invokeMethod("enableNativeLiquidGlassInfoButton", arguments: nil)
            
            // Create view model
            let viewModel = SSHLoginViewModel()
            self.viewModel = viewModel
            
            // Set up callbacks
            viewModel.onConnect = { [weak self] ip, port, username, password, privateKey, passphrase in
                self?.methodChannel?.invokeMethod("onConnectTapped", arguments: [
                    "ip": ip,
                    "port": port,
                    "username": username,
                    "password": password,
                    "privateKey": privateKey,
                    "privateKeyPassphrase": passphrase
                ])
            }
            
            viewModel.onLoadCredentials = { [weak self] in
                self?.methodChannel?.invokeMethod("onLoadCredentials", arguments: nil)
            }
            
            // Create SwiftUI view
            let sshScreen = NativeSSHLoginScreen(viewModel: viewModel)
            
            // Create hosting controller
            let hosting = UIHostingController(rootView: sshScreen)
            hosting.view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0)
            self.hostingController = hosting
            
            // Add as child view controller
            flutterViewController.addChild(hosting)
            flutterViewController.view.addSubview(hosting.view)
            hosting.didMove(toParent: flutterViewController)
            
            // Full screen constraints
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: flutterViewController.view.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: flutterViewController.view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: flutterViewController.view.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: flutterViewController.view.bottomAnchor)
            ])
            
            print("✅ Native SSH screen shown")
            result(true)
        }
    }
    
    private func hideNativeSSHScreen(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(false)
                return
            }
            
            // Hide the SSH screen view
            self.hostingController?.view.removeFromSuperview()
            self.hostingController?.removeFromParent()
            self.hostingController = nil
            self.viewModel = nil
            
            // Note: Don't hide Power/Info buttons here - they persist across screens
            // and are managed by the Flutter side
            
            print("✅ Native SSH screen hidden")
            result(true)
        }
    }
    
    private func loadCredentials(call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let viewModel = self.viewModel,
                  let args = call.arguments as? [String: Any] else {
                result(false)
                return
            }
            
            if let ip = args["ip"] as? String {
                viewModel.serverIP = ip
            }
            if let port = args["port"] as? String {
                viewModel.port = port
            }
            if let username = args["username"] as? String {
                viewModel.username = username
            }
            if let password = args["password"] as? String {
                viewModel.password = password
            }
            if let privateKey = args["privateKey"] as? String {
                viewModel.privateKey = privateKey
            }
            if let privateKeyPassphrase = args["privateKeyPassphrase"] as? String {
                viewModel.privateKeyPassphrase = privateKeyPassphrase
            }
            
            viewModel.stopRotation()
            print("✅ Credentials loaded into native SSH screen")
            result(true)
        }
    }
    
    private func stopLoading(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.stopLoading()
            result(true)
        }
    }
    
    private func showConnectionError(call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                result(false)
                return
            }
            
            let args = call.arguments as? [String: Any]
            let errorMessage = args?["message"] as? String ?? "Connection failed"
            
            let alert = UIAlertController(
                title: "Connection Failed",
                message: errorMessage,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            rootViewController.present(alert, animated: true)
            result(true)
        }
    }
}

