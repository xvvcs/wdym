import Foundation
import Security

protocol KeychainStore {
  func loadGroqAPIKey() -> String?
  func saveGroqAPIKey(_ apiKey: String) throws
  func deleteGroqAPIKey() throws
}

enum KeychainStoreError: Error {
  case unexpectedStatus(OSStatus)
  case invalidData
}

struct DefaultKeychainStore: KeychainStore {
  private let service = "wdym.promptrefactor"
  private let account = "groq_api_key"

  // On macOS, kSecAttrAccessible is only respected when kSecUseDataProtectionKeychain is set.
  // Using kSecUseDataProtectionKeychain causes KeychainStoreTests to fail in the test host;
  // keychain entitlements or test-environment access needs investigation before enabling.

  func loadGroqAPIKey() -> String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status != errSecItemNotFound else {
      return nil
    }

    guard status == errSecSuccess else {
      return nil
    }

    guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
      return nil
    }

    return value
  }

  func saveGroqAPIKey(_ apiKey: String) throws {
    let data = Data(apiKey.utf8)
    let accessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    let updateAttributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: accessible,
    ]
    let updateStatus = SecItemUpdate(
      baseQuery as CFDictionary,
      updateAttributes as CFDictionary
    )

    if updateStatus == errSecSuccess {
      return
    }

    if updateStatus != errSecItemNotFound {
      throw KeychainStoreError.unexpectedStatus(updateStatus)
    }

    var createQuery = baseQuery
    createQuery[kSecValueData as String] = data
    createQuery[kSecAttrAccessible as String] = accessible
    let addStatus = SecItemAdd(createQuery as CFDictionary, nil)

    guard addStatus == errSecSuccess else {
      throw KeychainStoreError.unexpectedStatus(addStatus)
    }
  }

  func deleteGroqAPIKey() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainStoreError.unexpectedStatus(status)
    }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
