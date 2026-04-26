package kanban

import "errors"

type ConflictCode string

const (
	ConflictBoardHasTasks          ConflictCode = "board_has_tasks"
	ConflictColumnHasTasks         ConflictCode = "column_has_tasks"
	ConflictColumnHasArchivedTasks ConflictCode = "column_has_archived_tasks"
	ConflictBoardTitleExists       ConflictCode = "board_title_exists"
)

type ConflictError struct {
	Code    ConflictCode
	Message string
}

func (e *ConflictError) Error() string {
	if e == nil || e.Message == "" {
		return ErrConflict.Error()
	}
	return e.Message
}

func (e *ConflictError) Is(target error) bool {
	return target == ErrConflict
}

func NewConflictError(code ConflictCode, message string) error {
	return &ConflictError{Code: code, Message: message}
}

func ConflictDetail(err error) string {
	if err == nil {
		return "conflict"
	}

	var conflictErr *ConflictError
	if errors.As(err, &conflictErr) {
		detail := conflictErr.Error()
		if detail == "" {
			return "conflict"
		}
		return detail
	}

	if errors.Is(err, ErrConflict) {
		return "conflict"
	}

	return err.Error()
}
