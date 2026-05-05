package sliceutil

import (
	"reflect"
	"testing"
)

func TestRemoveString(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name   string
		input  []string
		remove string
		want   []string
	}{
		{name: "removes existing item", input: []string{"a", "b", "c"}, remove: "b", want: []string{"a", "c"}},
		{name: "no-op when missing", input: []string{"a", "b"}, remove: "x", want: []string{"a", "b"}},
		{name: "removes first only", input: []string{"a", "b", "a"}, remove: "a", want: []string{"b", "a"}},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got := RemoveString(append([]string(nil), tc.input...), tc.remove)
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("RemoveString(%v, %q) = %v, want %v", tc.input, tc.remove, got, tc.want)
			}
		})
	}
}

func TestInsertStringAt(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name  string
		input []string
		index int
		value string
		want  []string
	}{
		{name: "insert at middle", input: []string{"a", "c"}, index: 1, value: "b", want: []string{"a", "b", "c"}},
		{name: "insert at start", input: []string{"b", "c"}, index: 0, value: "a", want: []string{"a", "b", "c"}},
		{name: "insert at end", input: []string{"a", "b"}, index: 2, value: "c", want: []string{"a", "b", "c"}},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got := InsertStringAt(append([]string(nil), tc.input...), tc.index, tc.value)
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("InsertStringAt(%v, %d, %q) = %v, want %v", tc.input, tc.index, tc.value, got, tc.want)
			}
		})
	}
}
