package handlers

import (
	"encoding/json"
	"net/http"

	"go_macos_todo/internal/auth"
)

type meResponse struct {
	UserID string `json:"userId"`
	Email  string `json:"email"`
}

func Me(w http.ResponseWriter, r *http.Request) {
	identity, ok := auth.GetIdentity(r.Context())
	if !ok {
		http.Error(w, "missing auth context", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(meResponse{
		UserID: identity.UserID,
		Email:  identity.Email,
	})
}
