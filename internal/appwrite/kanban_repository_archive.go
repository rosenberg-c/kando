package appwrite

import (
	"context"
	"sort"
	"time"

	"github.com/google/uuid"

	"go_macos_todo/internal/kanban"
)

func (r *KanbanRepository) CreateTaskWithArchivedAt(ctx context.Context, ownerUserID, boardID, columnID, title, description string, archivedAt *time.Time) (kanban.Task, kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	if _, err := r.getOwnedColumn(ctx, ownerUserID, boardID, columnID); err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	tasks, err := r.listTasks(ctx)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	position := 0
	isArchived := archivedAt != nil
	archivedTimestamp := time.Time{}
	if archivedAt != nil {
		archivedTimestamp = archivedAt.UTC().Truncate(time.Millisecond)
	}
	for _, td := range tasks {
		if td.ColumnID == columnID && td.IsArchived == isArchived && td.Position >= position {
			position = td.Position + 1
		}
	}

	now := time.Now().UTC()
	rowID := uuid.NewString()
	task := taskRow{
		ID:          rowID,
		BoardID:     boardID,
		ColumnID:    columnID,
		OwnerUserID: ownerUserID,
		Title:       title,
		Description: description,
		IsArchived:  isArchived,
		ArchivedAt:  archivedTimestamp,
		Position:    position,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	payload := map[string]any{"rowId": rowID, "data": taskCreateData(task)}
	if err := r.createRow(ctx, r.tasks, payload, nil); err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	task, err = r.getTaskRow(ctx, rowID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	return mapTaskRow(task), mapBoardRow(board), nil
}

func (r *KanbanRepository) ArchiveTasksInColumn(ctx context.Context, ownerUserID, boardID, columnID string) (kanban.ColumnTaskArchiveResult, kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.ColumnTaskArchiveResult{}, kanban.Board{}, err
	}
	if _, err := r.getOwnedColumn(ctx, ownerUserID, boardID, columnID); err != nil {
		return kanban.ColumnTaskArchiveResult{}, kanban.Board{}, err
	}

	tasks, err := r.listTasks(ctx)
	if err != nil {
		return kanban.ColumnTaskArchiveResult{}, kanban.Board{}, err
	}

	archivedAt := time.Now().UTC().Truncate(time.Millisecond)
	archivedAtRFC3339 := archivedAt.Format(time.RFC3339)
	archivedCount := 0
	for _, row := range tasks {
		if row.BoardID != boardID || row.ColumnID != columnID || row.OwnerUserID != ownerUserID || row.IsArchived {
			continue
		}
		payload := taskPatchPayload(row, map[string]any{
			"isArchived": true,
			"archivedAt": archivedAtRFC3339,
			"updatedAt":  archivedAtRFC3339,
		}, "")
		if err := r.updateRow(ctx, r.tasks, row.ID, payload, nil); err != nil {
			return kanban.ColumnTaskArchiveResult{}, kanban.Board{}, err
		}
		archivedCount++
	}

	if err := r.reindexTasks(ctx, columnID); err != nil {
		return kanban.ColumnTaskArchiveResult{}, kanban.Board{}, err
	}
	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.ColumnTaskArchiveResult{}, kanban.Board{}, err
	}

	return kanban.ColumnTaskArchiveResult{ArchivedTaskCount: archivedCount, ArchivedAt: archivedAt}, mapBoardRow(board), nil
}

func (r *KanbanRepository) ListArchivedTasksByBoard(ctx context.Context, ownerUserID, boardID string) ([]kanban.Task, error) {
	if _, err := r.getOwnedBoard(ctx, ownerUserID, boardID); err != nil {
		return nil, err
	}

	columns, err := r.listColumns(ctx)
	if err != nil {
		return nil, err
	}
	columnPositionByID := make(map[string]int)
	for _, column := range columns {
		if column.BoardID == boardID {
			columnPositionByID[column.ID] = column.Position
		}
	}

	tasks, err := r.listTasks(ctx)
	if err != nil {
		return nil, err
	}

	archivedRows := make([]taskRow, 0)
	for _, row := range tasks {
		if row.BoardID == boardID && row.OwnerUserID == ownerUserID && row.IsArchived {
			archivedRows = append(archivedRows, row)
		}
	}

	sort.Slice(archivedRows, func(i, j int) bool {
		leftPos, leftOK := columnPositionByID[archivedRows[i].ColumnID]
		rightPos, rightOK := columnPositionByID[archivedRows[j].ColumnID]
		if leftOK && rightOK && leftPos != rightPos {
			return leftPos < rightPos
		}
		if leftOK != rightOK {
			return leftOK
		}
		if !archivedRows[i].ArchivedAt.Equal(archivedRows[j].ArchivedAt) {
			return archivedRows[i].ArchivedAt.Before(archivedRows[j].ArchivedAt)
		}
		if archivedRows[i].Position != archivedRows[j].Position {
			return archivedRows[i].Position < archivedRows[j].Position
		}
		return archivedRows[i].ID < archivedRows[j].ID
	})

	result := make([]kanban.Task, 0, len(archivedRows))
	for _, row := range archivedRows {
		result = append(result, mapTaskRow(row))
	}
	return result, nil
}

func (r *KanbanRepository) RestoreArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (kanban.Task, kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	task, err := r.getOwnedArchivedTask(ctx, ownerUserID, boardID, taskID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	tasks, err := r.listTasks(ctx)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	position := 0
	for _, row := range tasks {
		if row.ColumnID == task.ColumnID && !row.IsArchived && row.Position >= position {
			position = row.Position + 1
		}
	}

	now := time.Now().UTC().Truncate(time.Millisecond)
	payload := taskPatchPayload(task, map[string]any{
		"isArchived": false,
		"archivedAt": nil,
		"position":   position,
		"updatedAt":  now.Format(time.RFC3339),
	}, "")
	if err := r.updateRow(ctx, r.tasks, task.ID, payload, nil); err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	task, err = r.getTaskRow(ctx, task.ID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	return mapTaskRow(task), mapBoardRow(board), nil
}

func (r *KanbanRepository) DeleteArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Board{}, err
	}

	task, err := r.getOwnedArchivedTask(ctx, ownerUserID, boardID, taskID)
	if err != nil {
		return kanban.Board{}, err
	}

	if err := r.deleteRow(ctx, r.tasks, task.ID); err != nil {
		return kanban.Board{}, err
	}

	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Board{}, err
	}
	return mapBoardRow(board), nil
}

func (r *KanbanRepository) getOwnedArchivedTask(ctx context.Context, ownerUserID, boardID, taskID string) (taskRow, error) {
	row, err := r.getTaskRow(ctx, taskID)
	if err != nil {
		return taskRow{}, err
	}
	if row.BoardID != boardID {
		return taskRow{}, kanban.ErrNotFound
	}
	if row.OwnerUserID != ownerUserID {
		return taskRow{}, kanban.ErrForbidden
	}
	if !row.IsArchived {
		return taskRow{}, kanban.ErrNotFound
	}
	return row, nil
}
