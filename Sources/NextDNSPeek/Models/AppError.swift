import Foundation

enum AppErrorKind: String {
  case unauthorized
  case rateLimited
  case offline
  case server
  case unknown
}

struct AppError: Identifiable {
  let id = UUID()
  let kind: AppErrorKind
  let message: String
  let at: Date
}
