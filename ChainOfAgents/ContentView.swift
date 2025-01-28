//
//  ContentView.swift
//  ChainOfAgents
//
//  Created by Rudrank Riyam on 1/28/25.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @StateObject private var viewModel = ChainOfAgentsViewModel()
  @State private var showingFilePicker = false

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 24) {
        // PDF Selection Section
        VStack(alignment: .leading, spacing: 12) {
          Text("Document")
            .font(.headline)

          Button(action: { showingFilePicker = true }) {
            HStack {
              Group {
                if let url = viewModel.selectedPDFURL {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                      .lineLimit(1)
                    Text("\(viewModel.pageCount) pages")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                } else {
                  Text("Select PDF Document")
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)

              Image(systemName: "doc.badge.plus")
                .foregroundColor(.blue)
            }
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.gray.opacity(0.2))
                )
            )
          }
          .buttonStyle(.plain)
        }

        // Query Section
        VStack(alignment: .leading, spacing: 12) {
          Text("Query")
            .font(.headline)

          TextField("Enter your question about the document...", text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
        }

        // Process Button
        Button(action: viewModel.processText) {
          if viewModel.isLoading {
            ProgressView()
              .controlSize(.small)
          } else {
            Text("Analyze Document")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isLoading || viewModel.selectedPDFURL == nil || viewModel.query.isEmpty)

        if let error = viewModel.error {
          Text(error)
            .font(.callout)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Spacer()
      }
      .padding()
      .frame(minWidth: 300)
      .navigationTitle("Input")
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [UTType.pdf],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let urls):
          guard let url = urls.first else { return }
          viewModel.selectPDF(url: url)
        case .failure(let error):
          viewModel.error = error.localizedDescription
        }
      }
    } detail: {
      // Results View
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if viewModel.isLoading {
            VStack(spacing: 16) {
              ProgressView("Processing Document...")
                .frame(maxWidth: .infinity, alignment: .center)

              // Progress Stats
              HStack(spacing: 20) {
                Label(
                  "\(viewModel.workerMessages.count) chunks processed",
                  systemImage: "doc.text.fill")
                Label(
                  "\(viewModel.pageCount) total pages",
                  systemImage: "book.fill")
              }
              .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
                .shadow(radius: 2)
            )
            .padding(.top, 40)
          }

          // Worker Messages
          if !viewModel.workerMessages.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                Text("Analysis Progress")
                  .font(.title2)
                  .bold()

                Spacer()

                // Progress indicator
                if viewModel.isLoading {
                  Label("Processing...", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                }
              }

              ForEach(viewModel.workerMessages) { message in
                WorkerResponseView(
                  message: message,
                  totalChunks: viewModel.totalChunks
                )
              }
            }
          }

          // Manager Message
          if !viewModel.managerMessage.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                Text("Final Summary")
                  .font(.title2)
                  .bold()

                if viewModel.isLoading {
                  Spacer()
                  ProgressView()
                    .scaleEffect(0.8)
                }
              }

              Text(viewModel.managerMessage)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                )
            }
          }

          Text("Total Chunks: \(viewModel.totalChunks)")  // Debug view
          Text("Current Progress: \(viewModel.workerMessages.count)/\(viewModel.totalChunks)")  // Debug view
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(minWidth: 500)
      .navigationTitle("Results")
      .background(Color(.windowBackgroundColor))
    }
  }
}

struct WorkerResponseView: View {
  let message: WorkerMessage
  let totalChunks: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      HStack {
        Label(
          "Worker \(message.id) of \(totalChunks)",
          systemImage: "person.fill"
        )
        .font(.headline)
        .foregroundColor(.blue)

        Spacer()

        if let progress = message.progress {
          Text("\(progress.current)/\(progress.total)")
            .foregroundColor(.secondary)
        }
      }

      // Progress Bar
      if let progress = message.progress {
        ProgressView(
          value: Double(progress.current),
          total: Double(progress.total)
        )
        .tint(.blue)
      }

      // Content
      Text(message.message)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color(.windowBackgroundColor))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(0.2))
            )
        )
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.blue.opacity(0.05))
    )
  }
}

#Preview {
  ContentView()
}
