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

  private var urlComponents: URLComponents = {
    var components = URLComponents()
    components.scheme = "http"
    components.host = "localhost"
    components.port = 5000
    components.path = "/process-stream"
    return components
  }()

  func processText() {
    guard let pdfURL = selectedPDFURL else {
      error = "Please select a PDF file first"
      return
    }

    guard !query.isEmpty else {
      error = "Please provide a query"
      return
    }

    Task {
      await processTextAsync(pdfURL: pdfURL)
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
      data.append(try Data(contentsOf: pdfURL))

      // Add query
      data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
      data.append("Content-Disposition: form-data; name=\"query\"\r\n\r\n".data(using: .utf8)!)
      data.append(query.data(using: .utf8)!)

      // Add final boundary
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
          let messages = str.split(separator: "\n")

          for message in messages where !message.isEmpty {
            if let data = message.data(using: .utf8),
              let streamMessage = try? JSONDecoder().decode(StreamMessage.self, from: data)
            {
              switch streamMessage.type {
              case "worker":
                workerMessages.append(
                  WorkerMessage(
                    id: workerMessages.count + 1,
                    message: streamMessage.content
                  ))
              case "manager":
                managerMessage = streamMessage.content
              default:
                break
              }
            }
          }

          currentData.removeAll()
        }
      }

    } catch NetworkError.serverError(let statusCode) {
      self.error = "Server error: \(statusCode)"
    } catch NetworkError.invalidResponse {
      self.error = "Invalid response from server"
    } catch {
      self.error = "Unexpected error: \(error.localizedDescription)"
    }

    isLoading = false
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
}

struct WorkerMessage: Identifiable {
  let id: Int
  let message: String
}

// MARK: - Errors
enum NetworkError: Error {
  case invalidResponse
  case serverError(statusCode: Int)
}
