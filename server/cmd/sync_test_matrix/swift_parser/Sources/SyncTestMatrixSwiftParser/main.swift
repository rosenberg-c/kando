import Foundation
import SwiftParser
import SwiftSyntax

struct ParsedTest: Codable {
    let name: String
    let line: Int
}

final class TestCollector: SyntaxVisitor {
    private let converter: SourceLocationConverter
    private var classXCTestCaseScope: [Bool] = []
    private(set) var tests: [ParsedTest] = []

    init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let inXCTestCase = classXCTestCaseScope.last ?? false
        let isXCTestStyleMethod = inXCTestCase && node.name.text.hasPrefix("test") && hasNoExplicitParameters(node.signature)
        guard hasTestAttribute(node.attributes) || isXCTestStyleMethod else {
            return .skipChildren
        }

        let location = converter.location(for: node.funcKeyword.positionAfterSkippingLeadingTrivia)
        tests.append(ParsedTest(name: node.name.text, line: location.line ?? 0))
        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        classXCTestCaseScope.append(inheritsFromXCTestCase(node.inheritanceClause))
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        if !classXCTestCaseScope.isEmpty {
            classXCTestCaseScope.removeLast()
        }
    }

    private func hasTestAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for element in attributes {
            guard case let .attribute(attribute) = element else {
                continue
            }

            let name = attribute.attributeName.trimmedDescription
            if name == "Test" || name.hasSuffix(".Test") {
                return true
            }
        }

        return false
    }

    private func hasNoExplicitParameters(_ signature: FunctionSignatureSyntax) -> Bool {
        signature.parameterClause.parameters.isEmpty
    }

    private func inheritsFromXCTestCase(_ inheritanceClause: InheritanceClauseSyntax?) -> Bool {
        guard let inheritanceClause else {
            return false
        }

        for inheritedType in inheritanceClause.inheritedTypes {
            let name = inheritedType.type.trimmedDescription
            if name == "XCTestCase" || name.hasSuffix(".XCTestCase") {
                return true
            }
        }

        return false
    }
}

func main() throws {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        throw NSError(domain: "sync-test-matrix-swift-parser", code: 1, userInfo: [NSLocalizedDescriptionKey: "usage: sync-test-matrix-swift-parser <swift-file-path> [swift-file-path ...]"])
    }

    let paths = Array(args.dropFirst())
    var resultByFile: [String: [ParsedTest]] = [:]

    for path in paths {
        let source = try String(contentsOfFile: path)
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: path, tree: tree)

        let visitor = TestCollector(converter: converter)
        visitor.walk(tree)
        resultByFile[path] = visitor.tests
    }

    let data = try JSONEncoder().encode(resultByFile)
    FileHandle.standardOutput.write(data)
}

do {
    try main()
} catch {
    let message = (error as NSError).localizedDescription
    FileHandle.standardError.write(Data(message.utf8))
    exit(1)
}
