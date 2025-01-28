//
//  ContentView.swift
//  ChainOfAgents
//
//  Created by Rudrank Riyam on 1/28/25.
//

import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = ChainOfAgentsViewModel()

  var body: some View {
    HSplitView {
      // Input Panel
      VStack(spacing: 20) {
        TextEditor(text: $viewModel.inputText)
          .font(.body)
          .frame(minHeight: 200)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.gray.opacity(0.2))
          )

        TextField("Enter your query", text: $viewModel.query)
          .textFieldStyle(RoundedBorderTextFieldStyle())

        Button(action: viewModel.processText) {
          if viewModel.isLoading {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text("Process")
          }
        }
        .disabled(viewModel.isLoading)

        if let error = viewModel.error {
          Text(error)
            .foregroundColor(.red)
        }
      }
      .padding()
      .frame(minWidth: 300)

      // Result Panel
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // Worker Messages
          if !viewModel.workerMessages.isEmpty {
            Text("Worker Responses")
              .font(.headline)

            ForEach(viewModel.workerMessages) { message in
              VStack(alignment: .leading, spacing: 8) {
                Text("Worker \(message.id)")
                  .font(.subheadline)
                  .foregroundColor(.secondary)

                Text(message.message)
                  .padding()
                  .background(Color.gray.opacity(0.1))
                  .cornerRadius(8)
              }
            }
          }

          // Manager Message
          if !viewModel.managerMessage.isEmpty {
            Text("Manager Response")
              .font(.headline)

            Text(viewModel.managerMessage)
              .padding()
              .background(Color.blue.opacity(0.1))
              .cornerRadius(8)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
      }
      .frame(minWidth: 300)
      .background(Color.gray.opacity(0.1))
    }
    .navigationTitle("Chain of Agents")
    .frame(minWidth: 800, minHeight: 500)
  }
}

#Preview {
  ContentView()
}
