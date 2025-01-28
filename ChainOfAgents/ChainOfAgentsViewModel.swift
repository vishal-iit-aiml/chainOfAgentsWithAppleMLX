//
//  ChainOfAgentsViewModel.swift
//  ChainOfAgents
//
//  Created by Rudrank Riyam on 1/28/25.
//

import PDFKit
import SwiftUI

@MainActor
final class ChainOfAgentsViewModel: ObservableObject {
  @Published var selectedPDFURL: URL?
  @Published var query = ""
  @Published var isLoading = false
  @Published var error: String?
  @Published var workerMessages: [WorkerMessage] = []
  @Published var managerMessage: String = ""
  @Published var pageCount: Int = 0
  @Published var isServerAvailable = false
  @Published var totalChunks: Int = 0

  // Add property to store security scope
  private var securityScopedBookmark: Data?

  private var urlComponents: URLComponents = {
    var components = URLComponents()
    components.scheme = "http"
    components.host = "localhost"
    components.port = 8000
    components.path = "/process-stream"
    return components
  }()

  init() {
    Task {
      await checkServerStatus()
    }
  }

  // Update the cleanup
  private func cleanup() {
    // Stop accessing the previous URL if it exists
    if let url = selectedPDFURL {
      url.stopAccessingSecurityScopedResource()
    }
    selectedPDFURL = nil
    securityScopedBookmark = nil
    workerMessages.removeAll()
    managerMessage = ""
    totalChunks = 0
  }

  // Handle file selection
  func selectPDF(url: URL) {
    cleanup()  // Clean up previous state

    guard url.startAccessingSecurityScopedResource() else {
      error = "Permission denied to access the file"
      return
    }

    // Create a security-scoped bookmark
    do {
      securityScopedBookmark = try url.bookmarkData(
        options: .minimalBookmark,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      selectedPDFURL = url

      if let pdfDocument = PDFDocument(url: url) {
        pageCount = pdfDocument.pageCount
      }

      error = nil
    } catch {
      url.stopAccessingSecurityScopedResource()
      self.error = "Could not create secure bookmark for file access"
    }
  }

  func processText() {
    guard let bookmark = securityScopedBookmark else {
      error = "Please select a PDF file first"
      return
    }

    guard !query.isEmpty else {
      error = "Please provide a query"
      return
    }

    // Resolve the bookmark to get a fresh URL with access
    do {
      var stale = false
      let url = try URL(
        resolvingBookmarkData: bookmark,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )

      if stale {
        error = "File access has expired, please select the file again"
        cleanup()
        return
      }

      guard url.startAccessingSecurityScopedResource() else {
        error = "Permission denied to access the file"
        return
      }

      Task {
        await processTextAsync(pdfURL: url)
      }
    } catch {
      self.error = "Could not access the file. Please select it again."
      cleanup()
    }
  }

  private func processTextAsync(pdfURL: URL) async {
    guard let url = urlComponents.url else {
      error = "Invalid URL configuration"
      return
    }

    isLoading = true
    error = nil
    workerMessages.removeAll()
    managerMessage = ""

    do {
      // Create multipart form data
      let boundary = UUID().uuidString
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue(
        "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
      request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

      // Create body
      var data = Data()

      // Add PDF file
      data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
      data.append(
        "Content-Disposition: form-data; name=\"pdf\"; filename=\"\(pdfURL.lastPathComponent)\"\r\n"
          .data(using: .utf8)!)
      data.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)

      // Get the file data while we have access
      let pdfData = try Data(contentsOf: pdfURL)
      data.append(pdfData)

      // Stop accessing the security-scoped resource
      pdfURL.stopAccessingSecurityScopedResource()

      // Add query and complete the request
      data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
      data.append("Content-Disposition: form-data; name=\"query\"\r\n\r\n".data(using: .utf8)!)
      data.append(query.data(using: .utf8)!)
      data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

      request.httpBody = data

      let (stream, response) = try await URLSession.shared.bytes(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw NetworkError.invalidResponse
      }

      guard httpResponse.statusCode == 200 else {
        throw NetworkError.serverError(statusCode: httpResponse.statusCode)
      }

      var currentData = Data()

      for try await byte in stream {
        currentData.append(byte)

        if let str = String(data: currentData, encoding: .utf8),
          str.contains("\n")
        {
          print("\n=== Received Raw Data ===")
          print(str)
          print("========================\n")

          let messages = str.split(separator: "\n")

          for message in messages where !message.isEmpty {
            print("\nProcessing message: \(message)")

            if let sseMessage = SSEMessage(rawMessage: String(message)) {
              let streamMessage = sseMessage.data

              switch streamMessage.type {
              case "metadata":
                if let metadataContent = streamMessage.content.data(using: .utf8),
                  let metadata = try? JSONDecoder().decode(
                    MetadataMessage.self, from: metadataContent)
                {
                  totalChunks = metadata.total_chunks
                }
              case "worker":
                workerMessages.append(
                  WorkerMessage(
                    id: workerMessages.count + 1,
                    message: streamMessage.content,
                    progress: streamMessage.progress
                  ))
              case "manager":
                managerMessage = streamMessage.content
              default:
                break
              }
            } else {
              print("Failed to decode SSE message")
            }
          }

          currentData.removeAll()
        }
      }

    } catch NetworkError.serverError(let statusCode) {
      self.error = "Server error: \(statusCode)"
    } catch NetworkError.invalidResponse {
      self.error = "Invalid response from server"
    } catch let error as URLError {
      switch error.code {
      case .cannotFindHost:
        self.error = "Cannot connect to server. Make sure the API server is running."
      case .networkConnectionLost:
        self.error = "Network connection lost. Please try again."
      case .notConnectedToInternet:
        self.error = "No internet connection available."
      default:
        self.error = "Network error: \(error.localizedDescription)"
      }
      pdfURL.stopAccessingSecurityScopedResource()
    } catch {
      pdfURL.stopAccessingSecurityScopedResource()
      self.error = "Unexpected error: \(error.localizedDescription)"
    }

    isLoading = false
  }

  private func checkServerStatus() async {
    guard let url = URL(string: "http://localhost:8000/health") else { return }

    do {
      let (_, response) = try await URLSession.shared.data(from: url)
      if let httpResponse = response as? HTTPURLResponse {
        isServerAvailable = httpResponse.statusCode == 200
      }
    } catch {
      isServerAvailable = false
      self.error = "Server not available. Please make sure the API server is running."
    }
  }
}

// MARK: - Models
struct ProcessRequest: Codable {
  let text: String
  let query: String
}

struct StreamMessage: Codable {
  let type: String
  let content: String
  let progress: ProgressInfo?

  struct ProgressInfo: Codable {
    let current: Int
    let total: Int
  }
}

struct MetadataMessage: Codable {
  let total_chunks: Int
  let total_pages: Int
}

struct WorkerMessage: Identifiable {
  let id: Int
  let message: String
  let progress: StreamMessage.ProgressInfo?
}

// MARK: - Errors
enum NetworkError: Error {
  case invalidResponse
  case serverError(statusCode: Int)
}

// Add this helper struct to parse SSE messages
private struct SSEMessage {
  let data: StreamMessage

  init?(rawMessage: String) {
    // Remove "data: " prefix
    guard rawMessage.hasPrefix("data: "),
      let jsonString = String(rawMessage.dropFirst(6)).data(using: .utf8),
      let message = try? JSONDecoder().decode(StreamMessage.self, from: jsonString)
    else {
      return nil
    }
    self.data = message
  }
}
