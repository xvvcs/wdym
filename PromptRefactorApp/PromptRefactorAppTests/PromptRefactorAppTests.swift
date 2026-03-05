//
//  PromptRefactorAppTests.swift
//  PromptRefactorAppTests
//
//  Created by Maciej Matuszewski on 04/03/2026.
//

import PromptRefactorCore
import Testing

@testable import PromptRefactorApp

@MainActor
struct PromptRefactorAppTests {
  @Test func outputModeTitlesMatchExpectedLabels() {
    #expect(OutputMode.replaceAndCopy.title == "Replace + Copy")
    #expect(OutputMode.replaceOnly.title == "Replace only")
    #expect(OutputMode.copyOnly.title == "Copy only")
  }

  @Test func outputModeBehaviorFlagsAreCorrect() {
    #expect(OutputMode.replaceAndCopy.shouldReplaceText)
    #expect(OutputMode.replaceAndCopy.shouldCopyText)

    #expect(OutputMode.replaceOnly.shouldReplaceText)
    #expect(!OutputMode.replaceOnly.shouldCopyText)

    #expect(!OutputMode.copyOnly.shouldReplaceText)
    #expect(OutputMode.copyOnly.shouldCopyText)
  }

  @Test func outputModeFallsBackToReplaceAndCopyForInvalidRawValue() {
    let resolved = OutputMode.from(rawValue: "invalid-value")

    #expect(resolved == .replaceAndCopy)
  }

  @Test func appRefactorPreferencesBuildsRefactorOptionsFromStoredValues() {
    let preferences = AppRefactorPreferences(
      outputModeRawValue: OutputMode.copyOnly.rawValue,
      promptStyleRawValue: PromptStyle.coding.rawValue,
      includeClarifyingQuestions: false
    )

    let options = preferences.buildOptions(language: "English")

    #expect(preferences.outputMode == .copyOnly)
    #expect(options.style == .coding)
    #expect(options.language == "English")
    #expect(!options.includeClarifyingQuestions)
  }

  @Test func appRefactorPreferencesFallsBackToGeneralPromptStyleWhenInvalid() {
    let preferences = AppRefactorPreferences(promptStyleRawValue: "not-a-style")

    #expect(preferences.promptStyle == .general)
  }

  @Test func appRefactorPreferencesCarriesCustomStylePromptWhenSelected() {
    let preferences = AppRefactorPreferences(
      promptStyleRawValue: PromptStyleSelection.custom(name: "Security Review").rawValue,
      customPromptStyles: securityReviewCustomStyles
    )

    let options = preferences.buildOptions()

    #expect(preferences.promptStyle == .general)
    #expect(
      options.customStylePrompt
        == "Ask for threat model assumptions before implementation details.")
  }

  @Test func appRefactorPreferencesResolvesCustomStylePromptCaseInsensitively() {
    let preferences = AppRefactorPreferences(
      promptStyleRawValue: PromptStyleSelection.custom(name: "security review").rawValue,
      customPromptStyles: securityReviewCustomStyles
    )

    let options = preferences.buildOptions()

    #expect(
      options.customStylePrompt
        == "Ask for threat model assumptions before implementation details.")
  }

  @Test func appRefactorPreferencesReturnsNilCustomStylePromptWhenCustomStyleIsMissing() {
    let preferences = AppRefactorPreferences(
      promptStyleRawValue: PromptStyleSelection.custom(name: "Missing").rawValue,
      customPromptStyles: []
    )

    let options = preferences.buildOptions()

    #expect(options.customStylePrompt == nil)
  }

  @Test func promptStyleDisplayTitlesMatchOptionsLabels() {
    #expect(PromptStyle.general.displayTitle == "General")
    #expect(PromptStyle.coding.displayTitle == "Coding")
    #expect(PromptStyle.writing.displayTitle == "Writing")
  }

  @Test func groqModelFallbackUsesSpeedFirstDefault() {
    let model = GroqModel.from(rawValue: "unknown-model")

    #expect(model == .llama31_8bInstant)
  }

  private var securityReviewCustomStyles: [CustomPromptStyle] {
    [
      CustomPromptStyle(
        name: "Security Review",
        prompt: "Ask for threat model assumptions before implementation details."
      )
    ]
  }
}
