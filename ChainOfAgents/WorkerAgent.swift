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
    private let modelConfiguration = ModelRegistry.llama3_1_8B_4bit
    private let generateParameters = GenerateParameters(temperature: 0.3)
    private let systemPrompt = """
    You are a worker agent responsible for analyzing a portion of a document.
    Your task is to identify key information related to the user's query and provide clear, concise analysis.
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
        
        let prompt = """
        Process the following document chunk and answer the following query, considering the previous cognitive unit if provided.
        
        Query: \(query)
        
        Document chunk:
        \(chunk)
        
        Previous Cognitive Unit: \(previousCU ?? "None")
        
        Provide a concise analysis focusing only on relevant information for the query, building upon previous context if available.
        """
        
        let result = try await modelContainer.perform { [prompt] context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
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

