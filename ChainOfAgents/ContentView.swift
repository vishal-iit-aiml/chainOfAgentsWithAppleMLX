//
//  ContentView.swift
//  ChainOfAgents
//
//  Created by Rudrank Riyam on 1/28/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

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
          viewModel.selectedPDFURL = url

          // Get page count if needed
          if let pdfDocument = PDFDocument(url: url) {
            viewModel.pageCount = pdfDocument.pageCount
          }

          viewModel.error = nil
        case .failure(let error):
          viewModel.error = error.localizedDescription
        }
      }
    } detail: {
      // Results View
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if viewModel.isLoading {
            ProgressView("Analyzing document...")
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.top, 40)
          }

          // Worker Messages
          if !viewModel.workerMessages.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              Text("Analysis Progress")
                .font(.title2)
                .bold()

              ForEach(viewModel.workerMessages) { message in
                WorkerResponseView(message: message)
              }
            }
          }

          // Manager Message
          if !viewModel.managerMessage.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              Text("Final Summary")
                .font(.title2)
                .bold()

              Text(viewModel.managerMessage)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                )
            }
          }
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

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Section \(message.id)")
        .font(.headline)
        .foregroundColor(.secondary)

      Text(message.message)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color(.windowBackgroundColor))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.2))
            )
        )
    }
  }
}

#Preview {
  ContentView()
}
