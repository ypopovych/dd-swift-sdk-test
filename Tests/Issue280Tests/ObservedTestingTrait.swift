/*
 * Custom wrapper trait, mirroring the `TestObservabilityTrait` / `.observedTesting`
 * setup described in https://github.com/DataDog/dd-sdk-swift-testing/issues/280
 *
 * The reporter does NOT attach the SDK's `.datadogTesting` trait directly.
 * Instead they wrap it in their own `TestTrait & SuiteTrait & TestScoping` type
 * that forwards `prepare` / `scopeProvider` / `provideScope` to the SDK trait and
 * injects extra tags around the test body. Reproducing that wrapper is important
 * because the wrapping is a prime suspect for the "parameterized failure not
 * propagated to the process exit code" behavior.
 */

import Testing
import Foundation
import DatadogSDKTesting

/// Minimal map of test-id -> tags. Mirrors the reporter's `DatadogTagMap`
/// without pulling in their full machinery.
struct DatadogTagMap: Sendable {
    private let tags: [String: [String: String]]

    init(tags: [String: [String: String]] = [:]) {
        self.tags = tags
    }

    func tags(for testID: String) -> [(String, String)]? {
        tags[testID].map { Array($0) }
    }

    /// Mirrors the helper referenced by the reporter's wrapper.
    static func normalizeSwiftTestingNameComponents(_ components: [String]) -> String {
        components.joined(separator: ".")
    }
}

public struct TestObservabilityTrait: TestTrait, SuiteTrait, TestScoping {
    public typealias TestScopeProvider = Self
    public typealias TraitProxy = any (TestTrait & SuiteTrait)

    let _inner: TraitProxy
    let tagMap: DatadogTagMap
    let setTag: @Sendable (_ key: String, _ value: String) -> Void

    init(
        traitProxy: TraitProxy = DatadogSwiftTestingTrait.datadogTesting,
        tagMap: DatadogTagMap = .init(),
        setTag: @escaping @Sendable (String, String) -> Void = { _, _ in }
    ) {
        self._inner = traitProxy
        self.tagMap = tagMap
        self.setTag = setTag
    }

    public var isRecursive: Bool { self._inner.isRecursive }

    public func prepare(for test: Testing.Test) async throws {
        try await self._inner.prepare(for: test)
    }

    public func scopeProvider(for test: Testing.Test, testCase: Testing.Test.Case?) -> Self? {
        self._inner.scopeProvider(for: test, testCase: testCase).map { _ in self }
    }

    public func provideScope(
        for test: Testing.Test,
        testCase: Testing.Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        guard let inner = self._inner.scopeProvider(for: test, testCase: testCase) else {
            try await function()
            return
        }

        try await inner.provideScope(
            for: test,
            testCase: testCase,
            performing: {
                let testID = DatadogTagMap.normalizeSwiftTestingNameComponents(test.id.nameComponents)

                guard let tags = self.tagMap.tags(for: testID) else {
                    try await function()
                    return
                }

                tags.forEach(self.setTag)

                try await function()
            }
        )
    }
}

extension Trait where Self == TestObservabilityTrait {
    /// Wrapper trait used by the suites in this repro, matching the issue report.
    public static var observedTesting: TestObservabilityTrait { TestObservabilityTrait() }
}
