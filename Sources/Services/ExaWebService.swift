//
//  ExaWebService.swift
//  FoundationModelsTools
//
//  Created by Rudrank Riyam on 6/15/25.
//

import Foundation

/// Service for interacting with the Exa API for web search
final class ExaWebService: Sendable {
  
  private let baseURL = "https://api.exa.ai/search"
  
  /// Performs a web search using the Exa API
  /// - Parameters:
  ///   - query: The search query
  ///   - apiKey: The Exa API key
  /// - Returns: ExaSearchResponse containing search results
  func search(query: String, apiKey: String) async throws -> ExaSearchResponse {
    guard let url = URL(string: baseURL) else {
      throw ExaWebServiceError.invalidURL
    }
    
    print("🔍 ExaWebService: Starting search for query: '\(query)'")
    
    let requestBody = ExaSearchRequest(
      query: query,
      type: "auto",
      numResults: 5,
      contents: ExaContents(text: true)
    )
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 15.0
    
    do {
      request.httpBody = try JSONEncoder().encode(requestBody)
    } catch {
      print("❌ ExaWebService: Failed to encode request body")
      throw ExaWebServiceError.encodingError
    }
    
    print("🌐 ExaWebService: Making request to: \(url.absoluteString)")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ExaWebServiceError.invalidResponse
    }
    
    print("📡 ExaWebService: Response status code: \(httpResponse.statusCode)")
    
    guard httpResponse.statusCode == 200 else {
      if let errorString = String(data: data, encoding: .utf8) {
        print("❌ ExaWebService: Error response: \(errorString)")
      }
      throw ExaWebServiceError.apiError(statusCode: httpResponse.statusCode)
    }
    
    print("✅ ExaWebService: Successfully received response (\(data.count) bytes)")
    
    // Debug: Print first 500 characters of response
    if let responseString = String(data: data, encoding: .utf8) {
      print("📄 ExaWebService: Response preview: \(responseString.prefix(500))...")
    }
    
    do {
      let searchResponse = try JSONDecoder().decode(ExaSearchResponse.self, from: data)
      print("🔍 ExaWebService: Successfully parsed \(searchResponse.results.count) results")
      return searchResponse
    } catch {
      print("❌ ExaWebService: Failed to decode response: \(error)")
      throw ExaWebServiceError.decodingError
    }
  }
}

// MARK: - Request/Response Models

/// Request body for Exa search API
struct ExaSearchRequest: Codable {
  let query: String
  let type: String
  let numResults: Int
  let contents: ExaContents
}

/// Contents configuration for Exa search
struct ExaContents: Codable {
  let text: Bool
}

/// Response from Exa search API
struct ExaSearchResponse: Codable {
  let requestId: String
  let resolvedSearchType: String
  let results: [ExaSearchResult]
  let searchType: String?
  let context: String?
  let costDollars: ExaCostInfo?
}

/// Individual search result from Exa
struct ExaSearchResult: Codable {
  let title: String
  let url: String
  let publishedDate: String?
  let author: String?
  let score: Double?
  let id: String
  let image: String?
  let favicon: String?
  let text: String?
  let highlights: [String]?
  let highlightScores: [Double]?
  let summary: String?
  let subpages: [ExaSubpage]?
  let extras: ExaExtras?
}

/// Subpage information from Exa results
struct ExaSubpage: Codable {
  let id: String
  let url: String
  let title: String
  let author: String?
  let publishedDate: String?
  let text: String?
  let summary: String?
  let highlights: [String]?
  let highlightScores: [Double]?
}

/// Extra information from Exa results
struct ExaExtras: Codable {
  let links: [String]?
}

/// Cost information from Exa API
struct ExaCostInfo: Codable {
  let total: Double
  let breakDown: [ExaCostBreakdown]?
  let perRequestPrices: ExaPerRequestPrices?
  let perPagePrices: ExaPerPagePrices?
}

struct ExaCostBreakdown: Codable {
  let search: Double?
  let contents: Double?
  let breakdown: ExaDetailedBreakdown?
}

struct ExaDetailedBreakdown: Codable {
  let keywordSearch: Double?
  let neuralSearch: Double?
  let contentText: Double?
  let contentHighlight: Double?
  let contentSummary: Double?
}

struct ExaPerRequestPrices: Codable {
  let neuralSearch_1_25_results: Double?
  let neuralSearch_26_100_results: Double?
  let neuralSearch_100_plus_results: Double?
  let keywordSearch_1_100_results: Double?
  let keywordSearch_100_plus_results: Double?
}

struct ExaPerPagePrices: Codable {
  let contentText: Double?
  let contentHighlight: Double?
  let contentSummary: Double?
}

// MARK: - Error Types

enum ExaWebServiceError: Error, LocalizedError {
  case invalidURL
  case encodingError
  case invalidResponse
  case apiError(statusCode: Int)
  case decodingError
  case missingAPIKey
  
  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid Exa API URL"
    case .encodingError:
      return "Failed to encode request data"
    case .invalidResponse:
      return "Invalid response from Exa API"
    case .apiError(let statusCode):
      return "Exa API error (Status: \(statusCode))"
    case .decodingError:
      return "Failed to decode Exa API response"
    case .missingAPIKey:
      return "Exa API key is required"
    }
  }
}