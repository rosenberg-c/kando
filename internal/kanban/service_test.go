package kanban

import (
	"context"
	"errors"
	"testing"
)

type serviceRepoStub struct {
	details           BoardDetails
	deleteColumnBoard Board
	getBoardCalls     int
	deleteColumnCalls int
	getBoardErr       error
	deleteColumnErr   error
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
	panic("unexpected call")
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

func (s *serviceRepoStub) CreateTodo(context.Context, string, string, string, string, string) (Todo, Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) UpdateTodo(context.Context, string, string, string, string, string) (Todo, Board, error) {
	panic("unexpected call")
}

func (s *serviceRepoStub) DeleteTodo(context.Context, string, string, string) (Board, error) {
	panic("unexpected call")
}

func TestServiceDeleteColumnWithTodosReturnsConflict(t *testing.T) {
	t.Parallel()

	stub := &serviceRepoStub{
		details: BoardDetails{Todos: []Todo{{ID: "todo-1", ColumnID: "column-1"}}},
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

func TestServiceDeleteColumnWithoutTodosDelegates(t *testing.T) {
	t.Parallel()

	stub := &serviceRepoStub{
		details:           BoardDetails{Todos: nil},
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
