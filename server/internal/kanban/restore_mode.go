package kanban

import "strings"

// RestoreBoardTitleMode controls which title to use when restoring an archived board.
type RestoreBoardTitleMode string

const (
	// RestoreBoardTitleModeOriginal restores the board with its pre-archive title.
	RestoreBoardTitleModeOriginal RestoreBoardTitleMode = "original"
	// RestoreBoardTitleModeArchived restores the board with its archived title.
	RestoreBoardTitleModeArchived RestoreBoardTitleMode = "archived"
)

// NormalizeRestoreBoardTitleMode validates and normalizes restore title mode input.
func NormalizeRestoreBoardTitleMode(value string) (RestoreBoardTitleMode, error) {
	mode := RestoreBoardTitleMode(strings.TrimSpace(value))
	switch mode {
	case RestoreBoardTitleModeOriginal, RestoreBoardTitleModeArchived:
		return mode, nil
	default:
		return "", ErrInvalidInput
	}
}
