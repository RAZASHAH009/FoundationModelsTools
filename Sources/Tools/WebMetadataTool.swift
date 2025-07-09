//
//  WebMetadataTool.swift
//  FoundationLab
//
//  Created by Rudrank Riyam on 6/29/25.
//

import Foundation
import FoundationModels
import LinkPresentation

/// `WebMetadataTool` extracts and provides metadata from web pages.
///
/// This tool fetches web page content and extracts useful metadata like title, description, etc.
/// Important: Requires network access to fetch web page content.
public struct WebMetadataTool: Tool {

  /// The name of the tool, used for identification.
  public let name = "getWebMetadata"
  /// A brief description of the tool's functionality.
  public let description =
    "Extract metadata and content from web pages including title, description, and text content"

  /// Arguments for web metadata extraction.
  @Generable
  public struct Arguments {
    /// The URL to extract metadata from
    @Guide(description: "The URL to extract metadata from")
    public var url: String

    /// Whether to include the full page content (default: false)
    @Guide(description: "Whether to include the full page content (default: false)")
    public var includeContent: Bool?

    /// Maximum content length to return (default: 1000 characters)
    @Guide(description: "Maximum content length to return (default: 1000 characters)")
    public var maxContentLength: Int?

    public init(
      url: String = "",
      includeContent: Bool? = nil,
      maxContentLength: Int? = nil
    ) {
      self.url = url
      self.includeContent = includeContent
      self.maxContentLength = maxContentLength
    }
  }

  public init() {}

  /// The metadata structure returned by the tool.
  public struct WebMetadata: Encodable {
    public let url: String
    public let title: String
    public let description: String
    public let imageURL: String?
    public let summary: String
    public let hashtags: [String]
    public let platform: String
  }

  public func call(arguments: Arguments) async throws -> ToolOutput {
    let urlString = arguments.url.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !urlString.isEmpty else {
      return createErrorOutput(for: urlString, error: WebMetadataError.emptyURL)
    }

    guard let url = URL(string: urlString) else {
      return createErrorOutput(for: urlString, error: WebMetadataError.invalidURL)
    }

    do {
      let metadata = try await fetchMetadata(from: url)
      let summary = try await generateSocialMediaSummary(
        metadata: metadata,
        platform: "general",  // Placeholder, as platform is not in Arguments
        includeHashtags: true  // Placeholder, as includeHashtags is not in Arguments
      )

      return createSuccessOutput(from: summary)
    } catch {
      return createErrorOutput(for: urlString, error: error)
    }
  }

  private func fetchMetadata(from url: URL) async throws -> LPLinkMetadata {
    let provider = LPMetadataProvider()

    do {
      let metadata = try await provider.startFetchingMetadata(for: url)
      return metadata
    } catch {
      throw WebMetadataError.fetchFailed(error)
    }
  }

  private func generateSocialMediaSummary(
    metadata: LPLinkMetadata,
    platform: String,
    includeHashtags: Bool
  ) async throws -> WebMetadata {
    let title = metadata.title ?? "Untitled"
    let description = metadata.value(forKey: "_summary") as? String ?? ""
    let imageURL = metadata.imageProvider != nil ? "Image available" : nil

    // Extract main content from the webpage if available
    let content = extractContent(from: metadata)

    // Generate AI-powered summary
    let session = LanguageModelSession()
    let prompt = createSummaryPrompt(
      title: title,
      description: description,
      content: content,
      platform: platform,
      includeHashtags: includeHashtags
    )

    let response = try await session.respond(to: Prompt(prompt))
    let summaryText = response.content

    // Extract hashtags from the summary
    let hashtags = extractHashtags(from: summaryText)

    return WebMetadata(
      url: metadata.url?.absoluteString ?? "",
      title: title,
      description: description,
      imageURL: imageURL,
      summary: summaryText,
      hashtags: hashtags,
      platform: platform
    )
  }

  private func extractContent(from metadata: LPLinkMetadata) -> String {
    // Try to extract additional content from metadata
    var content = ""

    if let summary = metadata.value(forKey: "_summary") as? String {
      content += summary + "\n\n"
    }

    // LinkPresentation doesn't provide full content access
    // In a real implementation, you might want to fetch and parse HTML
    // For now, we'll work with title and description

    return content
  }

  private func createSummaryPrompt(
    title: String,
    description: String,
    content: String,
    platform: String,
    includeHashtags: Bool
  ) -> String {
    let platformLimits = [
      "twitter": "280 characters",
      "linkedin": "3000 characters (but keep it concise, around 150-300 characters)",
      "facebook": "500 characters",
      "general": "200-300 characters",
    ]

    let limit = platformLimits[platform.lowercased()] ?? platformLimits["general"]!

    var prompt = """
      Create a compelling social media post summary for the following webpage:

      Title: \(title)
      Description: \(description)
      \(content.isEmpty ? "" : "Content: \(content)")

      Requirements:
      - Platform: \(platform)
      - Character limit: \(limit)
      - Make it engaging and shareable
      - Include a call-to-action if appropriate
      - Focus on the key takeaway or most interesting aspect
      """

    if includeHashtags {
      prompt += "\n- Include 3-5 relevant hashtags at the end"
    }

    return prompt
  }

  private func extractHashtags(from text: String) -> [String] {
    let pattern = #"#\w+"#
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let matches =
      regex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []

    return matches.compactMap { match in
      if let range = Range(match.range, in: text) {
        return String(text[range])
      }
      return nil
    }
  }

  private func createSuccessOutput(from metadata: WebMetadata) -> ToolOutput {
    return ToolOutput(
      GeneratedContent(properties: [
        "status": "success",
        "url": metadata.url,
        "title": metadata.title,
        "description": metadata.description,
        "imageURL": metadata.imageURL ?? "",
        "summary": metadata.summary,
        "hashtags": metadata.hashtags.joined(separator: " "),
        "platform": metadata.platform,
        "message": "Successfully generated social media summary",
      ])
    )
  }

  private func createErrorOutput(for url: String, error: Error) -> ToolOutput {
    return ToolOutput(
      GeneratedContent(properties: [
        "status": "error",
        "url": url,
        "error": error.localizedDescription,
        "summary": "",
        "message": "Failed to fetch metadata or generate summary",
      ])
    )
  }
}

enum WebMetadataError: Error, LocalizedError {
  case emptyURL
  case invalidURL
  case fetchFailed(Error)
  case summaryGenerationFailed

  var errorDescription: String? {
    switch self {
    case .emptyURL:
      return "URL cannot be empty"
    case .invalidURL:
      return "Invalid URL format"
    case .fetchFailed(let error):
      return "Failed to fetch metadata: \(error.localizedDescription)"
    case .summaryGenerationFailed:
      return "Failed to generate social media summary"
    }
  }
}
