package kanban

import (
	"context"
	"errors"
	"testing"
)

type serviceRepoStub struct {
	details             BoardDetails
	createBoardResult   Board
	deleteColumnBoard   Board
	reorderTasksBoard   Board
	reorderColumnsBoard Board
	createBoardCalls    int
	getBoardCalls       int
	deleteColumnCalls   int
	reorderTasksCalls   int
	reorderColumnsCalls int
	createBoardErr      error
	getBoardErr         error
	deleteColumnErr     error
	reorderTasksErr     error
	reorderColumnsErr   error
}

func (s *serviceRepoStub) ListBoardsByOwner(context.Context, string) ([]Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) GetBoard(context.Context, string, string) (BoardDetails, error) {
	s.getBoardCalls++
	if s.getBoardErr != nil {
		return BoardDetails{}, s.getBoardErr
	}
	return s.details, nil
}

func (s *serviceRepoStub) CreateBoard(context.Context, string, string) (Board, error) {
	s.createBoardCalls++
	if s.createBoardErr != nil {
		return Board{}, s.createBoardErr
	}
	return s.createBoardResult, nil
}

func (s *serviceRepoStub) UpdateBoardTitle(context.Context, string, string, string) (Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) DeleteBoard(context.Context, string, string) error {
	panic("unexpected call")
}

func (s *serviceRepoStub) CreateColumn(context.Context, string, string, string) (Column, Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) UpdateColumnTitle(context.Context, string, string, string, string) (Column, Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) DeleteColumn(context.Context, string, string, string) (Board, error) {
	s.deleteColumnCalls++
	if s.deleteColumnErr != nil {
		return Board{}, s.deleteColumnErr
	}
	return s.deleteColumnBoard, nil
}

func (s *serviceRepoStub) ReorderColumns(context.Context, string, string, []string) (Board, error) {
	s.reorderColumnsCalls++
	if s.reorderColumnsErr != nil {
		return Board{}, s.reorderColumnsErr
	}
	return s.reorderColumnsBoard, nil
}

func (s *serviceRepoStub) CreateTask(context.Context, string, string, string, string, string) (Task, Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) UpdateTask(context.Context, string, string, string, string, string) (Task, Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) ReorderTasks(context.Context, string, string, []TaskColumnOrder) (Board, error) {
	s.reorderTasksCalls++
	if s.reorderTasksErr != nil {
		return Board{}, s.reorderTasksErr
	}
	return s.reorderTasksBoard, nil
}

func (s *serviceRepoStub) DeleteTask(context.Context, string, string, string) (Board, error) {
	panic("unexpected call")
}

func TestServiceDeleteColumnWithTasksReturnsConflict(t *testing.T) {
	// Requirement: COL-RULE-001
	t.Parallel()

	stub := &serviceRepoStub{
		details: BoardDetails{Tasks: []Task{{ID: "task-1", ColumnID: "column-1"}}},
	}
	svc := NewService(stub)

	_, err := svc.DeleteColumn(context.Background(), "user-1", "board-1", "column-1")
	if !errors.Is(err, ErrConflict) {
		t.Fatalf("delete column err = %v, want ErrConflict", err)
	}
	if stub.getBoardCalls != 1 {
		t.Fatalf("get board calls = %d, want 1", stub.getBoardCalls)
	}
	if stub.deleteColumnCalls != 0 {
		t.Fatalf("delete column calls = %d, want 0", stub.deleteColumnCalls)
	}
}

func TestServiceDeleteColumnWithoutTasksDelegates(t *testing.T) {
	// Requirement: COL-003
	t.Parallel()

	stub := &serviceRepoStub{
		details:           BoardDetails{Tasks: nil},
		deleteColumnBoard: Board{ID: "board-1"},
	}
	svc := NewService(stub)

	board, err := svc.DeleteColumn(context.Background(), "user-1", "board-1", "column-1")
	if err != nil {
		t.Fatalf("delete column: %v", err)
	}
	if board.ID != "board-1" {
		t.Fatalf("board id = %q, want %q", board.ID, "board-1")
	}
	if stub.getBoardCalls != 1 {
		t.Fatalf("get board calls = %d, want 1", stub.getBoardCalls)
	}
	if stub.deleteColumnCalls != 1 {
		t.Fatalf("delete column calls = %d, want 1", stub.deleteColumnCalls)
	}
}

func TestServiceCreateBoardDelegatesAtomicConflict(t *testing.T) {
	t.Parallel()

	stub := &serviceRepoStub{
		createBoardErr: ErrConflict,
	}
	svc := NewService(stub)

	_, err := svc.CreateBoard(context.Background(), "user-1", "Main")
	if !errors.Is(err, ErrConflict) {
		t.Fatalf("create board err = %v, want ErrConflict", err)
	}
	if stub.createBoardCalls != 1 {
		t.Fatalf("create board calls = %d, want 1", stub.createBoardCalls)
	}
}

func TestServiceReorderTasksRejectsEmptyList(t *testing.T) {
	// Requirement: API-005
	t.Parallel()

	stub := &serviceRepoStub{}
	svc := NewService(stub)

	_, err := svc.ReorderTasks(context.Background(), "user-1", "board-1", nil)
	if !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("reorder tasks err = %v, want ErrInvalidInput", err)
	}
	if stub.reorderTasksCalls != 0 {
		t.Fatalf("reorder tasks calls = %d, want 0", stub.reorderTasksCalls)
	}
}

func TestServiceReorderColumnsRejectsEmptyList(t *testing.T) {
	// Requirement: COL-MOVE-006
	t.Parallel()

	stub := &serviceRepoStub{}
	svc := NewService(stub)

	_, err := svc.ReorderColumns(context.Background(), "user-1", "board-1", nil)
	if !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("reorder columns err = %v, want ErrInvalidInput", err)
	}
	if stub.reorderColumnsCalls != 0 {
		t.Fatalf("reorder columns calls = %d, want 0", stub.reorderColumnsCalls)
	}
}

func TestServiceReorderColumnsDelegates(t *testing.T) {
	// Requirement: COL-MOVE-001
	t.Parallel()

	stub := &serviceRepoStub{reorderColumnsBoard: Board{ID: "board-1"}}
	svc := NewService(stub)

	board, err := svc.ReorderColumns(context.Background(), "user-1", "board-1", []string{"a", "b"})
	if err != nil {
		t.Fatalf("reorder columns: %v", err)
	}
	if board.ID != "board-1" {
		t.Fatalf("board id = %q, want %q", board.ID, "board-1")
	}
	if stub.reorderColumnsCalls != 1 {
		t.Fatalf("reorder columns calls = %d, want 1", stub.reorderColumnsCalls)
	}
}

func TestServiceReorderTasksDelegates(t *testing.T) {
	// Requirement: TASK-005
	t.Parallel()

	stub := &serviceRepoStub{
		reorderTasksBoard: Board{ID: "board-1"},
	}
	svc := NewService(stub)

	board, err := svc.ReorderTasks(context.Background(), "user-1", "board-1", []TaskColumnOrder{{ColumnID: "column-1", TaskIDs: []string{"task-1"}}})
	if err != nil {
		t.Fatalf("reorder tasks: %v", err)
	}
	if board.ID != "board-1" {
		t.Fatalf("board id = %q, want %q", board.ID, "board-1")
	}
	if stub.reorderTasksCalls != 1 {
		t.Fatalf("reorder tasks calls = %d, want 1", stub.reorderTasksCalls)
	}
}
