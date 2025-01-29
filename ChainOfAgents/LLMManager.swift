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
    var isDownloading = false
    var downloadProgress = 0.0

    private let worker: WorkerAgent
    private let manager: ManagerAgent

    init() {
        self.worker = WorkerAgent()
        self.manager = ManagerAgent()
    }

    func processChunk(_ chunk: String, query: String, previousCU: String? = nil) async throws -> String {
        guard !running else { return "" }
        running = true

        do {
            // Delegate to WorkerAgent
            let result = try await worker.processChunk(chunk, query: query, previousCU: previousCU)
            running = false
            return result

        } catch {
            running = false
            throw error
        }
    }

    func updateContext(managerContext: String, workerResponse: String, query: String) async throws -> String {
        try await manager.updateContext(currentContext: managerContext, workerResponse: workerResponse, query: query)
    }
}
