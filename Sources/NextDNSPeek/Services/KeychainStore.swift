import Foundation
import Security

enum KeychainError: Error {
  case unexpectedStatus(OSStatus)
}

final class KeychainStore {
  private let account = "nextdns-api-token"

  private var service: String {
    let bundleId = Bundle.main.bundleIdentifier ?? "com.nextdns.peek"
    return bundleId + ".nextdns-peek"
  }

  func saveToken(_ token: String) throws {
    let data = Data(token.utf8)
    let query = baseQuery()
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var addQuery = query
      addQuery[kSecValueData as String] = data
      addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainError.unexpectedStatus(addStatus)
      }
    } else if status != errSecSuccess {
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func loadToken() throws -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = kCFBooleanTrue
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw KeychainError.unexpectedStatus(status)
    }
    guard let data = result as? Data,
          let token = String(data: data, encoding: .utf8) else {
      return nil
    }
    return token
  }

  func deleteToken() throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)
    if status == errSecItemNotFound {
      return
    }
    guard status == errSecSuccess else {
      throw KeychainError.unexpectedStatus(status)
    }
  }

  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}
