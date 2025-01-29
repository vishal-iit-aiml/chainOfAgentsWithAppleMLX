//
//  ManagerAgent.swift
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
final class ManagerAgent {
    private let modelConfiguration = ModelRegistry.llama3_2_3B_4bit
    private let generateParameters = GenerateParameters(temperature: 0.3)
    private let systemPrompt = """
    You are a manager agent responsible for synthesizing information from multiple workers.
    Your task is to combine their analyses into a coherent, comprehensive response that directly answers the user's query.
    """

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
            )

            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    func synthesize(_ workerOutputs: [String], query: String) async throws -> String {
        let modelContainer = try await load()
        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let combinedOutputs = workerOutputs.enumerated()
            .map { "Worker \($0.offset + 1): \($0.element)" }
            .joined(separator: "\n\n")

        let userPrompt = """
        Based on the following analyses from worker agents, provide a comprehensive answer to the query.
        
        Query: \(query)
        
        Worker Analyses:
        \(combinedOutputs)
        
        Provide a clear, well-organized final summary that directly addresses the query.
        """

        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        let result = try await modelContainer.perform { [messages] context in
            let input = try await context.processor.prepare(input: .init(messages: messages))
            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParameters,
                context: context
            ) { _ in
                return .more
            }
        }

        return result.output
    }
}
