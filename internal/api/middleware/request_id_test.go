package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRequestIDPreservesIncomingHeader(t *testing.T) {
	// Requirement: MW-REQID-001
	const incomingRequestID = "req-123"

	var downstreamRequestID string
	handler := RequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		downstreamRequestID = GetRequestID(r.Context())
		w.WriteHeader(http.StatusNoContent)
	}))

	req := httptest.NewRequest(http.MethodGet, "/hello", nil)
	req.Header.Set(requestIDHeader, incomingRequestID)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if got := rec.Header().Get(requestIDHeader); got != incomingRequestID {
		t.Fatalf("response request ID = %q, want %q", got, incomingRequestID)
	}

	if downstreamRequestID != incomingRequestID {
		t.Fatalf("context request ID = %q, want %q", downstreamRequestID, incomingRequestID)
	}
}

func TestRequestIDGeneratesWhenMissing(t *testing.T) {
	// Requirement: MW-REQID-002
	var downstreamRequestID string
	handler := RequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		downstreamRequestID = GetRequestID(r.Context())
		w.WriteHeader(http.StatusNoContent)
	}))

	req := httptest.NewRequest(http.MethodGet, "/hello", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	responseRequestID := rec.Header().Get(requestIDHeader)
	if responseRequestID == "" {
		t.Fatal("response request ID is empty")
	}

	if downstreamRequestID == "" {
		t.Fatal("context request ID is empty")
	}

	if downstreamRequestID != responseRequestID {
		t.Fatalf("context request ID = %q, want %q", downstreamRequestID, responseRequestID)
	}
}
