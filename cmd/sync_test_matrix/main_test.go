package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCollectFromFileFindsAdjacentRequirementTags(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	path := filepath.Join(root, "sample_test.go")
	content := `package sample

// @req API-001
func TestAboveTag(t *testing.T) {
}

func TestInlineTag(t *testing.T) {
	// @req AUTH-001, AUTH-002
}

func TestIgnoresNonCommentTag(t *testing.T) {
	_ = "@req API-999"
}
`

	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write sample test file: %v", err)
	}

	refs := map[string][]string{}
	if err := collectFromGoFile(root, path, refs); err != nil {
		t.Fatalf("collect from file: %v", err)
	}

	assertHasRef(t, refs, "API-001", "sample_test.go", "TestAboveTag")
	assertHasRef(t, refs, "AUTH-001", "sample_test.go", "TestInlineTag")
	assertHasRef(t, refs, "AUTH-002", "sample_test.go", "TestInlineTag")

	if _, exists := refs["API-999"]; exists {
		t.Fatalf("unexpected ref for API-999: %+v", refs["API-999"])
	}
}

// @req TEST-HARNESS-001
func TestCollectFromFileSupportsAdjacentMultiLineRequirementComments(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	path := filepath.Join(root, "multiline_test.go")
	content := `package sample

// @req API-001, API-003
// @req UX-001, UX-002
func TestMultiLineAbove(t *testing.T) {
}
`

	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write multiline test file: %v", err)
	}

	refs := map[string][]string{}
	if err := collectFromGoFile(root, path, refs); err != nil {
		t.Fatalf("collect from file: %v", err)
	}

	assertHasRef(t, refs, "API-001", "multiline_test.go", "TestMultiLineAbove")
	assertHasRef(t, refs, "API-003", "multiline_test.go", "TestMultiLineAbove")
	assertHasRef(t, refs, "UX-001", "multiline_test.go", "TestMultiLineAbove")
	assertHasRef(t, refs, "UX-002", "multiline_test.go", "TestMultiLineAbove")
}

func TestCollectAdjacentTagIDsSupportsConsecutiveBelowComments(t *testing.T) {
	t.Parallel()

	lines := []string{
		"func TestFromBelow(t *testing.T) {",
		"// @req CLI-001, CLI-002",
		"// @req CLI-003",
		"}",
	}

	ids := collectAdjacentTagIDs(lines, 0)
	assertContainsID(t, ids, "CLI-001")
	assertContainsID(t, ids, "CLI-002")
	assertContainsID(t, ids, "CLI-003")
}

func TestCollectFromFileIgnoresFixtureStringsThatLookLikeTests(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	path := filepath.Join(root, "fixture_test.go")
	content := "package sample\n\n" +
		"var fixture = `\n" +
		"// @req API-001\n" +
		"func TestNotReal(t *testing.T) {}\n" +
		"`\n\n" +
		"// @req AUTH-001\n" +
		"func TestReal(t *testing.T) {\n" +
		"}\n"

	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write fixture test file: %v", err)
	}

	refs := map[string][]string{}
	if err := collectFromGoFile(root, path, refs); err != nil {
		t.Fatalf("collect from file: %v", err)
	}

	assertHasRef(t, refs, "AUTH-001", "fixture_test.go", "TestReal")
	if _, exists := refs["API-001"]; exists {
		t.Fatalf("unexpected fixture-derived ref for API-001: %+v", refs["API-001"])
	}
}

func TestUpdateMatrixPrunesUnknownRequirements(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "TEST_MATRIX.md")
	initial := `# Test Matrix

## Coverage Map

| Requirement ID | Coverage Type | Test References | Status | Notes |
| --- | --- | --- | --- | --- |
| ` + "`OLD-999`" + ` | API integration | - | Gap | stale |
| ` + "`API-001`" + ` | API integration | - | Gap | note |
`
	if err := os.WriteFile(path, []byte(initial), 0o644); err != nil {
		t.Fatalf("write matrix: %v", err)
	}

	refs := map[string][]string{
		"API-001": {"`internal/api/server/server_test.go` (`TestKanbanBoardColumnTaskCRUD`)"},
	}

	updated, _, err := updateMatrix(path, []string{"API-001"}, refs)
	if err != nil {
		t.Fatalf("update matrix: %v", err)
	}

	if strings.Contains(updated, "`OLD-999`") {
		t.Fatalf("expected OLD-999 row to be pruned\n%s", updated)
	}
	if !strings.Contains(updated, "| `API-001` | API integration | `internal/api/server/server_test.go` (`TestKanbanBoardColumnTaskCRUD`) | Covered | note |") {
		t.Fatalf("expected API-001 row to be covered with generated ref\n%s", updated)
	}
}

func TestUpdateMatrixPreservesPartialStatusWhenTagged(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "TEST_MATRIX.md")
	initial := `# Test Matrix

## Coverage Map

| Requirement ID | Coverage Type | Test References | Status | Notes |
| --- | --- | --- | --- | --- |
| ` + "`APPWRITE-002`" + ` | Integration contract | - | Partial | pagination note |
`
	if err := os.WriteFile(path, []byte(initial), 0o644); err != nil {
		t.Fatalf("write matrix: %v", err)
	}

	refs := map[string][]string{
		"APPWRITE-002": {"`internal/kanban/repository_contract_appwrite_integration_test.go` (`TestRepositoryContractAppwriteService`)"},
	}

	updated, _, err := updateMatrix(path, []string{"APPWRITE-002"}, refs)
	if err != nil {
		t.Fatalf("update matrix: %v", err)
	}

	if !strings.Contains(updated, "| `APPWRITE-002` | Integration contract | `internal/kanban/repository_contract_appwrite_integration_test.go` (`TestRepositoryContractAppwriteService`) | Partial | pagination note |") {
		t.Fatalf("expected Partial status to be preserved\n%s", updated)
	}
}

func TestUpdateMatrixAddsManagedNotice(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "TEST_MATRIX.md")
	initial := `# Test Matrix

## Coverage Map

| Requirement ID | Coverage Type | Test References | Status | Notes |
| --- | --- | --- | --- | --- |
| ` + "`API-001`" + ` | API integration | - | Gap | note |
`
	if err := os.WriteFile(path, []byte(initial), 0o644); err != nil {
		t.Fatalf("write matrix: %v", err)
	}

	updated, _, err := updateMatrix(path, []string{"API-001"}, map[string][]string{})
	if err != nil {
		t.Fatalf("update matrix: %v", err)
	}

	if !strings.Contains(updated, matrixManagedNotice) {
		t.Fatalf("expected managed notice in updated matrix\n%s", updated)
	}
}

func assertHasRef(t *testing.T, refs map[string][]string, id, file, testName string) {
	t.Helper()

	items := refs[id]
	if len(items) == 0 {
		t.Fatalf("missing refs for %s", id)
	}

	expected := "`" + file + "` (`" + testName + "`)"
	for _, item := range items {
		if item == expected {
			return
		}
	}

	t.Fatalf("missing expected ref %q in %+v", expected, items)
}

func assertContainsID(t *testing.T, ids []string, expected string) {
	t.Helper()
	for _, id := range ids {
		if id == expected {
			return
		}
	}
	t.Fatalf("missing expected id %q in %+v", expected, ids)
}
