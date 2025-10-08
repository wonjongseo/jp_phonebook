import UIKit
import Flutter
import CallKit

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    private let channelName = "call_directory_channel"
    private let appGroupId = "group.com.wonjongseo.jpphonebook"
    private let extensionBundleId = "com.wonjongseo.jp-phonebook.PhoneBookCallDirectory"
    private let jsonFileName = "call_directory.json"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "updateIdentifiers":
                guard let jsonStr = call.arguments as? String,
                      let data = jsonStr.data(using: .utf8) else {
                    result(FlutterError(code: "BAD_ARGS", message: "Invalid payload", details: nil))
                    return
                }
                do {
                    try self.saveJsonToAppGroup(data: data)
                    result(nil)
                } catch {
                    result(FlutterError(code: "SAVE_FAIL", message: error.localizedDescription, details: nil))
                }
                
            case "reloadExtension":
                self.reloadCallDirectory { ok in result(ok) }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
            
    private func saveJsonToAppGroup(data: Data) throws {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            throw NSError(domain: "AppGroup", code: -1, userInfo: [NSLocalizedDescriptionKey: "App Group container not found"])
        }
        let url = containerURL.appendingPathComponent(jsonFileName)
       
        if let s = String(data: data, encoding: .utf8) {
            print("App: will save JSON -> \(s)")
        } else {
            print("App: will save JSON (binary \(data.count) bytes)")
        }
        
        try data.write(to: url, options: .atomic)

        let back = try Data(contentsOf: url)
        print("App: saved JSON bytes=\(back.count)")
        if let s2 = String(data: back, encoding: .utf8) {
            print("App: saved JSON echo -> \(s2)")
        }
    }
    // MARK: - Reload Extension
    private func reloadCallDirectory(completion: @escaping (Bool) -> Void) {
        let manager = CXCallDirectoryManager.sharedInstance
        manager.reloadExtension(withIdentifier: extensionBundleId) { error in
            if let error = error {
                NSLog("CallDirectory reload error: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
