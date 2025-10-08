import Foundation
import CallKit
import os.log

final class CallDirectoryHandler: CXCallDirectoryProvider {
  private let appGroupId   = "group.com.wonjongseo.jpphonebook"
  private let jsonFileName = "call_directory.json"

  struct Entry: Decodable {
    let number: String
    let label: String
  }
  struct Payload: Decodable {
    let entries: [Entry]
  }

  override func beginRequest(with context: CXCallDirectoryExtensionContext) {
    context.delegate = self
    os_log("CD: beginRequest called")

    addAllIdentification(to: context)

    context.completeRequest()
  }

  private func addAllIdentification(to context: CXCallDirectoryExtensionContext) {
    guard let containerURL = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
      os_log("CD: containerURL nil"); return
    }

    let url = containerURL.appendingPathComponent(jsonFileName)
    guard let data = try? Data(contentsOf: url) else {
      os_log("CD: json not found"); return
    }

    // JSON은 {"entries":[{"number":"...","label":"..."}]}
    guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
      os_log("CD: json decode failed")
      return
    }

    // 숫자만 → Int64 → 오름차순
    var normalized: [(Int64, String)] = []
    normalized.reserveCapacity(payload.entries.count)
    for e in payload.entries {
      let digits = e.number.filter { ("0"..."9").contains($0) }
      if let num = Int64(digits), !e.label.isEmpty {
        normalized.append((num, e.label))
      }
    }
    normalized.sort { $0.0 < $1.0 }

    for (num, label) in normalized {
      context.addIdentificationEntry(withNextSequentialPhoneNumber: num, label: label)
    }

    // 🔎 디버그 지표 기록: 적용 건수/시각
    if let d = UserDefaults(suiteName: appGroupId) {
      d.set(normalized.count, forKey: "cd_last_applied_count")
      d.set(Date().timeIntervalSince1970, forKey: "cd_last_applied_at")
    }
    os_log("CD: applied count=%{public}d", normalized.count)
  }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
  func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
    os_log("CD: requestFailed: %{public}@", error.localizedDescription)
  }
}
