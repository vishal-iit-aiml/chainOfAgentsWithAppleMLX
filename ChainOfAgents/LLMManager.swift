//
//  LLMManager.swift
//  ChainOfAgents
//
//  Created by Rudrank Riyam
//

import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom

@Observable
@MainActor
final class LLMManager {
    var running = false
    var output = ""
    var modelInfo = ""
    var stat = ""
    var messages: [WorkerMessage] = []
    var managerMessage = ""

    let modelConfiguration = ModelRegistry.llama3_2_3B_4bit
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 240

    private enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    private var loadState = LoadState.idle

    private func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo = "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                }
            }

            let numParams = await modelContainer.perform { context in
                context.model.numParameters()
            }

            self.modelInfo = "Loaded \(modelConfiguration.id). Weights: \(numParams / (1024*1024))M"
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    func processChunk(_ chunk: String, query: String) async throws -> String {
        guard !running else { return "" }

        running = true

        do {
            let modelContainer = try await load()
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            
            let prompt = """
Process the following document chunk and answer the following query: \(query)
            
Document chunk:
\(chunk)

Provide a concise analysis focusing only on relevant information for the query.
"""

            let result = try await modelContainer.perform { [prompt] context in
                let input = try await context.processor.prepare(input: .init(prompt: prompt))
                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters, context: context
                ) { tokens in
                    let text = context.tokenizer.decode(tokens: tokens)
                    return .more
                }
            }

            running = false
            return result.output

        } catch {
            running = false
            throw error
        }
    }

    func summarizeResponses(_ responses: [String], query: String) async throws -> String {
        guard !running else { return "" }

        running = true

        do {
            let modelContainer = try await load()
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            
            let combinedResponses = responses.enumerated()
                .map { "Analysis \($0.offset + 1): \($0.element)" }
                .joined(separator: "\n\n")

            let prompt = """
Based on the following analyses of document chunks, provide a comprehensive answer to the query: \(query)
            
\(combinedResponses)

Provide a clear, well-organized summary that directly addresses the query.
"""

            let result = try await modelContainer.perform { [prompt] context in
                let input = try await context.processor.prepare(input: .init(prompt: prompt))
                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters, context: context
                ) { tokens in
                    let text = context.tokenizer.decode(tokens: tokens)
                    return .more
                }
            }

            running = false
            return result.output

        } catch {
            running = false
            throw error
        }
    }
}

