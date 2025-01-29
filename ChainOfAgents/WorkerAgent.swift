//
//  WorkerAgent.swift
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
final class WorkerAgent {
    private let modelConfiguration = ModelRegistry.llama3_2_3B_4bit
    private let generateParameters = GenerateParameters(temperature: 0.3)
    private let systemPrompt = """
    You are a worker agent responsible for analyzing a portion of a document.
    Your task is to identify key information related to the user's query and provide clear, concise analysis.
    
    If the current chunk doesn't contain information relevant to the query, maintain continuity by acknowledging 
    and building upon the previous analysis without adding redundant or irrelevant information.
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

    func processChunk(_ chunk: String, query: String, previousCU: String? = nil) async throws -> String {
        let modelContainer = try await load()
        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let contextMemory = previousCU ?? "No previous context available."

        let userPrompt = """
        Review the worker analysis carefully.

        Query: \(query)

        Previous Context:
        \(contextMemory)

        Current Chunk:
        \(chunk)

        1. Detect any contradictions or inconsistencies.
        2. Ensure all key points are covered and reinforced if needed.
        3. Generate a refined, final response.
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
