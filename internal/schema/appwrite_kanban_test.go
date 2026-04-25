package schema

import "testing"

func TestKanbanAppwriteDatabaseIncludesBoardOwnerArchivedUpdatedIndex(t *testing.T) {
	database := KanbanAppwriteDatabase()

	var boards *AppwriteTable
	for i := range database.Tables {
		if database.Tables[i].ID == "boards" {
			boards = &database.Tables[i]
			break
		}
	}
	if boards == nil {
		t.Fatal("boards table missing")
	}

	for _, index := range boards.Indexes {
		if index.Key != "boards_owner_archived_updated" {
			continue
		}
		if index.Type != "key" {
			t.Fatalf("boards_owner_archived_updated type = %q, want %q", index.Type, "key")
		}
		if len(index.Columns) != 3 || index.Columns[0] != "ownerUserId" || index.Columns[1] != "isArchived" || index.Columns[2] != "updatedAt" {
			t.Fatalf("boards_owner_archived_updated columns = %v, want [ownerUserId isArchived updatedAt]", index.Columns)
		}
		return
	}

	t.Fatal("boards_owner_archived_updated index missing")
}
