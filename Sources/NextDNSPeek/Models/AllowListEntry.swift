import Foundation

struct AllowListEntry: Identifiable, Equatable {
  let id: String
  var domain: String
  var isEnabled: Bool
}
