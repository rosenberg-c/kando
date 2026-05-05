package main

import "testing"

func TestValidateLogSizeWarnAndError(t *testing.T) {
	warn, err := validateLogSize(6*mb, 5*mb, 10*mb)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !warn {
		t.Fatal("expected warning for size above warn threshold")
	}

	warn, err = validateLogSize(11*mb, 5*mb, 10*mb)
	if err == nil {
		t.Fatal("expected error for size above max threshold")
	}
	if warn {
		t.Fatal("did not expect warning when already errored")
	}
}
