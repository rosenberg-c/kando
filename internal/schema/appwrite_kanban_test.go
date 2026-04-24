package schema

import "testing"

func TestKanbanAppwriteDatabaseIncludesBoardOwnerUpdatedIndex(t *testing.T) {
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
		if index.Key != "boards_owner_updated" {
			continue
		}
		if index.Type != "key" {
			t.Fatalf("boards_owner_updated type = %q, want %q", index.Type, "key")
		}
		if len(index.Columns) != 2 || index.Columns[0] != "ownerUserId" || index.Columns[1] != "updatedAt" {
			t.Fatalf("boards_owner_updated columns = %v, want [ownerUserId updatedAt]", index.Columns)
		}
		return
	}

	t.Fatal("boards_owner_updated index missing")
}
