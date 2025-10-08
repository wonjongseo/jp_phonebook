import Foundation
import CallKit
import os.log

final class CallDirectoryHandler: CXCallDirectoryProvider {
  private let appGroupId   = "group.com.wonjongseo.jpphonebook"
  private let jsonFileName = "call_directory.json"
  private let defaultCountryCode = "81" // 일본

  struct Entry: Decodable { let number: String; let label: String }
  struct Payload: Decodable { let entries: [Entry] }

  override func beginRequest(with context: CXCallDirectoryExtensionContext) {
    context.delegate = self
    os_log("CD: beginRequest called")

    if #available(iOS 11.0, *) {
      if context.isIncremental {
        // ✅ 증분 호출: 기존 것 전부 삭제 후 다시 추가
        context.removeAllIdentificationEntries()
        os_log("CD: incremental=true → removeAllIdentificationEntries")
        addAllIdentification(to: context)
      } else {
        // ✅ 비증분 호출: 전체 재구성 (이전 데이터는 교체됨)
        os_log("CD: incremental=false → full rebuild")
        addAllIdentification(to: context)
      }
    } else {
      // ✅ iOS 10: 증분 미지원 → 전체 재구성만
      os_log("CD: iOS10 full rebuild")
      addAllIdentification(to: context)
    }

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

    guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
      os_log("CD: json decode failed"); return
    }

    // 정규화 + 중복 제거
    var map: [Int64: String] = [:]
    map.reserveCapacity(payload.entries.count)

    for e in payload.entries {
      if let num = normalizeToE164Digits(e.number, defaultCC: defaultCountryCode),
         !e.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        map[num] = e.label // 같은 번호 중복 오면 마지막 라벨로 덮어씀
      }
    }

    let sorted = map.keys.sorted()
    for num in sorted {
      context.addIdentificationEntry(withNextSequentialPhoneNumber: num,
                                     label: map[num] ?? "")
    }

    if let d = UserDefaults(suiteName: appGroupId) {
      d.set(sorted.count, forKey: "cd_last_applied_count")
      d.set(Date().timeIntervalSince1970, forKey: "cd_last_applied_at")
    }
    os_log("CD: applied count=%{public}d", sorted.count)
  }

  /// 입력을 국가코드 포함 "숫자만(E.164 digits, '+' 제거)"로 정규화 → Int64
  /// 예) "070 1234 5678" → 817012345678
  private func normalizeToE164Digits(_ raw: String, defaultCC: String) -> Int64? {
    // 0) 전각 → 반각
    let half = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw

    // 1) 허용 문자(+, 0-9)만 남김
    let allowed = CharacterSet(charactersIn: "+0123456789")
    var s = half.unicodeScalars.filter { allowed.contains($0) }
      .map(String.init).joined()

    // 2) 앞의 '+' 제거
    if s.hasPrefix("+") { s.removeFirst() }

    // 3) 국제접속프리픽스 '00' 제거 (예: 0081... → 81...)
    if s.hasPrefix("00") { s.removeFirst(2) }

    // 현재 s: 숫자만

    // 4) 이미 국가코드로 시작? (예: 81...)
    if s.hasPrefix(defaultCC) {
      // '81' 다음이 '0'이면 국내 트렁크 '0'으로 보고 제거
      let ccEnd = s.index(s.startIndex, offsetBy: defaultCC.count)
      if ccEnd < s.endIndex, s[ccEnd] == "0" {
        s.remove(at: ccEnd)
      }
      return Int64(s)
    }

    // 5) 국내형(선행 0) → 선행 0 한 개 제거 후 국가코드 prepend
    if s.hasPrefix("0") {
      s.removeFirst()
      s = defaultCC + s
      return Int64(s)
    }

    // 6) 그 외(예: 7012345678) → 국가코드 prepend
    s = defaultCC + s
    return Int64(s)
  }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
  func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
    os_log("CD: requestFailed: %{public}@", error.localizedDescription)
  }
}
