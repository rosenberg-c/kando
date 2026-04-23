package kanban

import (
	"errors"
	"testing"
)

func TestReorderIDs(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name                string
		ids                 []string
		targetID            string
		destinationPosition int
		want                []string
		wantErr             error
	}{
		{
			name:                "move to start",
			ids:                 []string{"a", "b", "c"},
			targetID:            "c",
			destinationPosition: 0,
			want:                []string{"c", "a", "b"},
		},
		{
			name:                "move to end",
			ids:                 []string{"a", "b", "c"},
			targetID:            "a",
			destinationPosition: 2,
			want:                []string{"b", "c", "a"},
		},
		{
			name:                "no-op move",
			ids:                 []string{"a", "b", "c"},
			targetID:            "b",
			destinationPosition: 1,
			want:                []string{"a", "b", "c"},
		},
		{
			name:                "missing target",
			ids:                 []string{"a", "b", "c"},
			targetID:            "x",
			destinationPosition: 0,
			wantErr:             ErrNotFound,
		},
		{
			name:                "negative destination",
			ids:                 []string{"a", "b", "c"},
			targetID:            "a",
			destinationPosition: -1,
			wantErr:             ErrInvalidInput,
		},
		{
			name:                "destination out of range",
			ids:                 []string{"a", "b", "c"},
			targetID:            "a",
			destinationPosition: 3,
			wantErr:             ErrInvalidInput,
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			input := append([]string(nil), tc.ids...)
			got, err := ReorderIDs(input, tc.targetID, tc.destinationPosition)
			if tc.wantErr != nil {
				if !errors.Is(err, tc.wantErr) {
					t.Fatalf("err = %v, want %v", err, tc.wantErr)
				}
				return
			}

			if err != nil {
				t.Fatalf("reorder ids: %v", err)
			}
			if len(got) != len(tc.want) {
				t.Fatalf("len(got) = %d, want %d", len(got), len(tc.want))
			}
			for i := range tc.want {
				if got[i] != tc.want[i] {
					t.Fatalf("got[%d] = %q, want %q", i, got[i], tc.want[i])
				}
			}
			for i := range tc.ids {
				if input[i] != tc.ids[i] {
					t.Fatalf("input mutated at %d: got %q want %q", i, input[i], tc.ids[i])
				}
			}
		})
	}
}

func TestValidateExactOrder(t *testing.T) {
	t.Parallel()

	current := []string{"a", "b", "c"}
	if err := ValidateExactOrder(current, []string{"c", "a", "b"}); err != nil {
		t.Fatalf("validate exact order valid: %v", err)
	}

	cases := []struct {
		name      string
		candidate []string
	}{
		{name: "missing id", candidate: []string{"a", "b"}},
		{name: "extra id", candidate: []string{"a", "b", "c", "d"}},
		{name: "unknown id", candidate: []string{"a", "b", "x"}},
		{name: "duplicate id", candidate: []string{"a", "a", "b"}},
		{name: "empty id", candidate: []string{"a", "", "c"}},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if err := ValidateExactOrder(current, tc.candidate); err != ErrInvalidInput {
				t.Fatalf("err = %v, want %v", err, ErrInvalidInput)
			}
		})
	}
}
