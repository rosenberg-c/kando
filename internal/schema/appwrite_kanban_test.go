package schema

import "testing"

func TestKanbanAppwriteDatabaseIncludesUniqueBoardOwnerIndex(t *testing.T) {
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
		if index.Key != "boards_owner_unique" {
			continue
		}
		if index.Type != "unique" {
			t.Fatalf("boards_owner_unique type = %q, want %q", index.Type, "unique")
		}
		if len(index.Columns) != 1 || index.Columns[0] != "ownerUserId" {
			t.Fatalf("boards_owner_unique columns = %v, want [ownerUserId]", index.Columns)
		}
		return
	}

	t.Fatal("boards_owner_unique index missing")
}
