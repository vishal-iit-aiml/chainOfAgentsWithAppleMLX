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

    func updateContext(currentContext: String, workerResponse: String, query: String) async throws -> String {
        let modelContainer = try await load()
        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let prompt = """
             You are a manager agent. Your current knowledge is:
             
             \(currentContext)
             
             A worker agent has provided the following analysis related to the query '\(query)':
             
             \(workerResponse)
             
             Update your current knowledge by integrating the worker's analysis, resolving any inconsistencies, and summarizing the most relevant information in the context of the query.
             """

        // 3. Generate the updated context using the model
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": prompt]
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
        // 4. Return the updated context
        return result.output
    }
}
