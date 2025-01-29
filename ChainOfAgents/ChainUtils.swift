//
//  ChainUtils.swift
//  ChainOfAgents
//
//  Created by Rudrank Riyam
//

import Foundation
import PDFKit

struct ChainUtils {
    static func splitIntoChunks(text: String, chunkSize: Int) -> [String] {
        // Split by paragraphs first to maintain context
        let paragraphs = text.components(separatedBy: "\n\n")
        var currentChunk: [String] = []
        var chunks: [String] = []
        
        for paragraph in paragraphs {
            guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            
            let paragraphWords = paragraph.split(separator: " ").map(String.init)
            
            // If adding this paragraph exceeds chunk size, save current chunk and start new one
            if currentChunk.count + paragraphWords.count > chunkSize {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.joined(separator: " "))
                    currentChunk.removeAll()
                }
                
                // Handle paragraphs larger than chunkSize
                var remainingWords = paragraphWords
                while remainingWords.count > chunkSize {
                    chunks.append(remainingWords[..<chunkSize].joined(separator: " "))
                    remainingWords = Array(remainingWords[chunkSize...])
                }
                
                currentChunk = Array(remainingWords)
            } else {
                currentChunk.append(contentsOf: paragraphWords)
            }
        }
        
        // Add any remaining text
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }
        
        return chunks
    }
    
    static func getDefaultPrompts() -> (worker: String, manager: String) {
        let workerPrompt = """
        You are a worker agent responsible for analyzing a portion of a document.
        Your task is to identify key information related to the user's query and provide clear, concise analysis.
        """
        
        let managerPrompt = """
        You are a manager agent responsible for synthesizing information from multiple workers.
        Your task is to combine their analyses into a coherent, comprehensive response that directly answers the user's query.
        """
        
        return (workerPrompt, managerPrompt)
    }
    
    static func extractText(from pdfDocument: PDFDocument) -> String {
        var text: [String] = []
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i) {
                text.append(page.string ?? "")
            }
        }
        return text.joined(separator: "\n")
    }
}

