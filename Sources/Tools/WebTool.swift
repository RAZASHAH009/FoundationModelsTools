//
//  WebTool.swift
//  FoundationModelsTools
//
//  Created by Rudrank Riyam on 6/15/25.
//

import Foundation
import FoundationModels
import SwiftUI

/// `WebTool` provides web search and research capabilities using Exa.
///
/// This tool can search the web for relevant content and information.
/// Important: This requires an Exa API key set in environment variables.
public struct WebTool: Tool {

  /// The name of the tool, used for identification.
  public let name = "searchWeb"
  /// A brief description of the tool's functionality.
  public let description = "Search the web for relevant content and information using Exa"

  /// Arguments for web search operations.
  @Generable
  public struct Arguments {
    /// The search query to execute
    @Guide(description: "The search query to execute")
    public var query: String

    /// Number of results to return (default: 5, max: 10)
    @Guide(description: "Number of results to return (default: 5, max: 10)")
    public var numResults: Int?

    /// Type of search: "neural" or "keyword" (default: "neural")
    @Guide(description: "Type of search: 'neural' or 'keyword' (default: 'neural')")
    public var type: String?

    /// Whether to include page contents (default: true)
    @Guide(description: "Whether to include page contents (default: true)")
    public var includeContents: Bool?

    /// Category filter (e.g., "news", "research", "company", "social")
    @Guide(description: "Category filter (e.g., 'news', 'research', 'company', 'social')")
    public var category: String?

    public init(
      query: String = "",
      numResults: Int? = nil,
      type: String? = nil,
      includeContents: Bool? = nil,
      category: String? = nil
    ) {
      self.query = query
      self.numResults = numResults
      self.type = type
      self.includeContents = includeContents
      self.category = category
    }
  }

  /// The search data returned by the tool.
  public struct SearchData: Encodable {
    /// The search query that was performed.
    public let query: String
    /// Abstract text from the search results.
    public let abstract: String
    /// Source of the abstract information.
    public let abstractSource: String
    /// URL for more information.
    public let abstractURL: String
    /// Related topics found.
    public let relatedTopics: [String]
    /// Search results summary.
    public let summary: String
  }

  private let exaService: ExaWebService

  /// AppStorage for the API key
  @AppStorage("exaAPIKey") private var exaAPIKey: String = ""

  public init() {
    self.exaService = ExaWebService()
  }

  public func call(arguments: Arguments) async throws -> ToolOutput {
    let searchQuery = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !searchQuery.isEmpty else {
      return createErrorOutput(for: searchQuery, error: WebError.emptyQuery)
    }

    guard !exaAPIKey.isEmpty else {
      return createErrorOutput(for: searchQuery, error: WebError.missingAPIKey)
    }

    do {
      let searchData = try await performWebSearch(query: searchQuery)
      return createSuccessOutput(from: searchData)
    } catch {
      return createErrorOutput(for: searchQuery, error: error)
    }
  }

  private func performWebSearch(query: String) async throws -> SearchData {
    do {
      let exaResponse = try await exaService.search(query: query, apiKey: exaAPIKey)

      return SearchData(
        query: query,
        abstract: extractMainContent(from: exaResponse),
        abstractSource: extractSource(from: exaResponse),
        abstractURL: extractURL(from: exaResponse),
        relatedTopics: extractRelatedTopics(from: exaResponse),
        summary: createSearchSummary(from: exaResponse, query: query)
      )
    } catch let exaError as ExaWebServiceError {
      throw WebError.exaServiceError(exaError)
    } catch {
      throw WebError.networkError(error)
    }
  }

  // Helper methods for extracting data from Exa Search response
  private func extractMainContent(from response: ExaSearchResponse) -> String {
    if let firstResult = response.results.first {
      return firstResult.summary ?? firstResult.text ?? ""
    }
    return ""
  }

  private func extractSource(from response: ExaSearchResponse) -> String {
    return response.results.first?.author ?? response.results.first?.title ?? ""
  }

  private func extractURL(from response: ExaSearchResponse) -> String {
    return response.results.first?.url ?? ""
  }

  private func extractRelatedTopics(from response: ExaSearchResponse) -> [String] {
    return response.results.prefix(3).map { $0.title }
  }

  private func createSearchSummary(from response: ExaSearchResponse, query: String) -> String {
    var summary = "Information about '\(query)':\n\n"

    if !response.results.isEmpty {
      // Combine text content from all results
      var combinedText = ""

      for result in response.results.prefix(3) {
        if let resultSummary = result.summary, !resultSummary.isEmpty {
          combinedText += "\(resultSummary)\n\n"
        } else if let text = result.text, !text.isEmpty {
          let truncatedText = String(text.prefix(300))
          combinedText += "\(truncatedText)...\n\n"
        }
      }

      summary += combinedText.isEmpty ? "No detailed text content available." : combinedText
    } else {
      summary += "No results found for this query."
    }

    return summary
  }

  private func createSuccessOutput(from searchData: SearchData) -> ToolOutput {
    return ToolOutput(
      GeneratedContent(properties: [
        "query": searchData.query,
        "abstract": searchData.abstract,
        "abstractSource": searchData.abstractSource,
        "relatedTopicsCount": searchData.relatedTopics.count,
        "summary": searchData.summary,
        "status": "success",
      ]))
  }

  private func createErrorOutput(for query: String, error: Error) -> ToolOutput {
    return ToolOutput(
      GeneratedContent(properties: [
        "query": query,
        "error": "Unable to perform web search: \(error.localizedDescription)",
        "abstract": "",
        "abstractSource": "",
        "relatedTopicsCount": 0,
        "summary": "Search failed for query: '\(query)'",
        "status": "error",
      ]))
  }
}

enum WebError: Error, LocalizedError {
  case emptyQuery
  case invalidURL
  case apiError
  case noResults
  case missingAPIKey
  case exaServiceError(ExaWebServiceError)
  case networkError(Error)

  var errorDescription: String? {
    switch self {
    case .emptyQuery:
      return "Search query cannot be empty"
    case .invalidURL:
      return "Invalid search URL"
    case .apiError:
      return "Web search API request failed"
    case .noResults:
      return "No search results found"
    case .missingAPIKey:
      return "Exa API key is required. Please configure it in Settings."
    case .exaServiceError(let exaError):
      return "Exa API error: \(exaError.localizedDescription)"
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    }
  }
}
