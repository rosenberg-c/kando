package middleware

import (
	"log"
	"net/http"
	"time"
)

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (r *statusRecorder) WriteHeader(statusCode int) {
	r.statusCode = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}

// RequestLogger logs method, path, status code, and duration for each request.
func RequestLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startedAt := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(recorder, r)

		log.Printf(
			"request_id=%s method=%s path=%s status=%d duration=%s",
			GetRequestID(r.Context()),
			r.Method,
			r.URL.Path,
			recorder.statusCode,
			time.Since(startedAt),
		)
	})
}
