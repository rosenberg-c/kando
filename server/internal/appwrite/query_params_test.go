package appwrite

import (
	"encoding/json"
	"net/url"
	"reflect"
	"testing"
)

func TestWithPagedQueriesBuildsAppwriteQueryArray(t *testing.T) {
	t.Parallel()

	path := withPagedQueries("/tablesdb/db/tables/tasks/rows", 100, 200)
	parsed, err := url.Parse(path)
	if err != nil {
		t.Fatalf("parse path: %v", err)
	}

	queryValues := parsed.Query()["queries[]"]
	if len(queryValues) != 2 {
		t.Fatalf("queries[] count = %d, want 2", len(queryValues))
	}

	var first map[string]any
	if err := json.Unmarshal([]byte(queryValues[0]), &first); err != nil {
		t.Fatalf("unmarshal first query: %v", err)
	}
	if first["method"] != "limit" {
		t.Fatalf("first method = %v, want %q", first["method"], "limit")
	}
	firstValues, ok := first["values"].([]any)
	if !ok {
		t.Fatalf("first values type = %T", first["values"])
	}
	if !reflect.DeepEqual(firstValues, []any{float64(100)}) {
		t.Fatalf("first values = %#v, want %#v", firstValues, []any{float64(100)})
	}

	var second map[string]any
	if err := json.Unmarshal([]byte(queryValues[1]), &second); err != nil {
		t.Fatalf("unmarshal second query: %v", err)
	}
	if second["method"] != "offset" {
		t.Fatalf("second method = %v, want %q", second["method"], "offset")
	}
	secondValues, ok := second["values"].([]any)
	if !ok {
		t.Fatalf("second values type = %T", second["values"])
	}
	if !reflect.DeepEqual(secondValues, []any{float64(200)}) {
		t.Fatalf("second values = %#v, want %#v", secondValues, []any{float64(200)})
	}
}

func TestWithPagedQueriesPreservesExistingQueryParams(t *testing.T) {
	t.Parallel()

	path := withPagedQueries("/tablesdb/db/tables/tasks/rows?total=true", 10, 20)
	parsed, err := url.Parse(path)
	if err != nil {
		t.Fatalf("parse path: %v", err)
	}

	if got := parsed.Query().Get("total"); got != "true" {
		t.Fatalf("total = %q, want %q", got, "true")
	}

	queryValues := parsed.Query()["queries[]"]
	if len(queryValues) != 2 {
		t.Fatalf("queries[] count = %d, want 2", len(queryValues))
	}
}

func TestWithPagedQueriesReturnsOriginalPathOnParseError(t *testing.T) {
	t.Parallel()

	malformedPath := "%"
	got := withPagedQueries(malformedPath, 10, 20)
	if got != malformedPath {
		t.Fatalf("path = %q, want %q", got, malformedPath)
	}
}
