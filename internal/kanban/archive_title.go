package kanban

import (
	"fmt"
	"time"
)

const archivedTitleTimestampLayout = "2006-01-02 15:04:05Z"

// ArchivedBoardTitle returns the archive display name with a UTC timestamp suffix.
func ArchivedBoardTitle(title string, at time.Time) string {
	timestamp := at.UTC().Format(archivedTitleTimestampLayout)
	return fmt.Sprintf("%s (archived %s)", title, timestamp)
}
