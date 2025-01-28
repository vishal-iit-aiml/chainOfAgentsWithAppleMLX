//
//  ChainOfAgentsViewModel.swift
//  ChainOfAgents
//
//  Created by Rudrank Riyam on 1/28/25.
//

import SwiftUI

@MainActor
final class ChainOfAgentsViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var query = ""
    @Published var result = ""
    @Published var isLoading = false
    @Published var error: String?

    private var urlComponents: URLComponents = {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = 5000
        components.path = "/process"
        return components
    }()

    func processText() {
        Task {
            await processTextAsync()
        }
    }

    private func processTextAsync() async {
        guard !inputText.isEmpty, !query.isEmpty else {
            error = "Please provide both input text and query"
            return
        }

        guard let url = urlComponents.url else {
            error = "Invalid URL configuration"
            return
        }

        isLoading = true
        error = nil

        do {
            let body = ProcessRequest(text: inputText, query: query)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }

            let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
            result = decodedResponse.result

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

struct Response: Codable {
    let result: String
}

// MARK: - Errors
enum NetworkError: Error {
    case invalidResponse
    case serverError(statusCode: Int)
}
