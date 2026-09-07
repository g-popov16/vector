#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
VERIFY_DIR=$(mktemp -d)
trap 'rm -rf "$VERIFY_DIR"' EXIT
# Reuse every XCTest test body with lightweight assertion adapters when Xcode is absent.
python3 - "$VERIFY_DIR/main.swift" <<'PY'
import re, sys
from pathlib import Path
tests = Path('Tests/VectorCoreTests/AnalyticsTests.swift').read_text()
tests = tests.replace('import XCTest', 'import Foundation').replace('@testable import VectorCore', '')
tests = tests.replace('final class AnalyticsTests: XCTestCase', 'final class AnalyticsTests')
adapter = '''
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value == nil, "Expected nil at \\(file):\\(line)") }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { precondition(a == b, "Expected \\(a) == \\(b) at \\(file):\\(line)") }
func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double) { precondition(abs(a - b) <= accuracy) }
func XCTAssertNotEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a != b) }
func XCTAssertLessThan<T: Comparable>(_ a: T, _ b: T) { precondition(a < b) }
func XCTAssertLessThanOrEqual<T: Comparable>(_ a: T, _ b: T) { precondition(a <= b) }
func XCTAssertGreaterThanOrEqual<T: Comparable>(_ a: T, _ b: T) { precondition(a >= b) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
'''
names = re.findall(r'func (test\w+)\(', tests)
Path(sys.argv[1]).write_text(adapter + tests + '\nlet suite = AnalyticsTests()\n' + '\n'.join(f'suite.{name}(); print("PASS {name}")' for name in names))
PY
swiftc Sources/VectorCore/*.swift "$VERIFY_DIR/main.swift" -o "$VERIFY_DIR/verify"
"$VERIFY_DIR/verify"
swiftc -frontend -parse Apps/iOS/*.swift
swiftc -frontend -parse Apps/Watch/*.swift
echo "Native Swift syntax passed. SDK type checking and device tests require Xcode."
