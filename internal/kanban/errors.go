package kanban

import "errors"

var (
	// ErrNotFound indicates that a board, column, or todo does not exist.
	ErrNotFound = errors.New("not found")
	// ErrForbidden indicates resource ownership mismatch.
	ErrForbidden = errors.New("forbidden")
	// ErrConflict indicates a write conflict such as stale version updates.
	ErrConflict = errors.New("conflict")
	// ErrInvalidInput indicates invalid mutation input at the repository boundary.
	ErrInvalidInput = errors.New("invalid input")
	// ErrNotImplemented is returned by adapter stubs that are not implemented yet.
	ErrNotImplemented = errors.New("not implemented")
)
