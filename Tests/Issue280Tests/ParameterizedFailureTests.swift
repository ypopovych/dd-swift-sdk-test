/*
 * Standalone reproduction for https://github.com/DataDog/dd-sdk-swift-testing/issues/280
 *
 * "SwiftTesting with Parameterized Test Doesn't Mark as Failure"
 *
 * Expectation: a failing test must make the test process exit with a non-zero
 * status so CI marks the job as failed. The bug report says that with the SDK
 * attached, a *parameterized* Swift Testing test is reported as failed in the
 * Datadog UI, yet the test process still exits 0 and CI stays green.
 *
 * The suites below let you compare the three relevant cases under one run:
 *   1. parameterized + failing   (the reported bug)
 *   2. non-parameterized + failing (control: should always exit non-zero)
 *   3. parameterized + passing    (control: should exit zero)
 */

import Testing
import DatadogSDKTesting

enum MyEnum: CaseIterable {
    case alpha, beta, gamma
}

// 1. The reported bug: parameterized + failing.
@Suite("Parameterized Failing", .observedTesting)
struct ParameterizedFailingTests {
    @Test(arguments: MyEnum.allCases)
    func failingParameterizedTest(enumValue: MyEnum) throws {
        // Fails for .beta and .gamma.
        #expect(enumValue == .alpha, "expected .alpha but got \(enumValue)")
    }
}

// 2. Control: non-parameterized + failing. Should reliably fail the process.
@Suite("Plain Failing", .observedTesting)
struct PlainFailingTests {
    @Test
    func failingTest() throws {
        #expect(Bool(false), "this test always fails")
    }
}

// 3. Control: parameterized + passing. Should keep the process green.
@Suite("Parameterized Passing", .observedTesting)
struct ParameterizedPassingTests {
    @Test(arguments: MyEnum.allCases)
    func passingParameterizedTest(enumValue: MyEnum) throws {
        #expect(MyEnum.allCases.contains(enumValue))
    }
}
