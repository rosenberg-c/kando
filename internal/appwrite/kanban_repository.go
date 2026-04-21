package appwrite

import (
	"context"
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"go_macos_todo/internal/kanban"
)

// KanbanRepositoryConfig defines the Appwrite database and table IDs used by KanbanRepository.
type KanbanRepositoryConfig struct {
	DatabaseID string
	BoardsID   string
	ColumnsID  string
	TasksID    string
}

// KanbanRepository persists kanban boards, columns, and tasks in Appwrite TablesDB.
type KanbanRepository struct {
	client   *Client
	database string
	boards   string
	columns  string
	tasks    string
}

type boardRow struct {
	ID           string    `json:"$id"`
	OwnerUserID  string    `json:"ownerUserId"`
	Title        string    `json:"title"`
	BoardVersion int       `json:"boardVersion"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

type columnRow struct {
	ID          string    `json:"$id"`
	BoardID     string    `json:"boardId"`
	OwnerUserID string    `json:"ownerUserId"`
	Title       string    `json:"title"`
	Position    int       `json:"position"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

type taskRow struct {
	ID          string    `json:"$id"`
	BoardID     string    `json:"boardId"`
	ColumnID    string    `json:"columnId"`
	OwnerUserID string    `json:"ownerUserId"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Position    int       `json:"position"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

type listRowsResponse[T any] struct {
	Total int `json:"total"`
	Rows  []T `json:"rows"`
}

const kanbanListRowsPageLimit = 100

// NewKanbanRepository creates an Appwrite-backed kanban repository using configured table IDs.
func NewKanbanRepository(client *Client, cfg KanbanRepositoryConfig) *KanbanRepository {
	if strings.TrimSpace(cfg.DatabaseID) == "" {
		cfg.DatabaseID = "task"
	}
	if strings.TrimSpace(cfg.BoardsID) == "" {
		cfg.BoardsID = "boards"
	}
	if strings.TrimSpace(cfg.ColumnsID) == "" {
		cfg.ColumnsID = "columns"
	}
	if strings.TrimSpace(cfg.TasksID) == "" {
		cfg.TasksID = "tasks"
	}

	return &KanbanRepository{
		client:   client,
		database: cfg.DatabaseID,
		boards:   cfg.BoardsID,
		columns:  cfg.ColumnsID,
		tasks:    cfg.TasksID,
	}
}

func (r *KanbanRepository) ListBoardsByOwner(ctx context.Context, ownerUserID string) ([]kanban.Board, error) {
	rows, err := r.listBoards(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]kanban.Board, 0, len(rows))
	for _, row := range rows {
		if row.OwnerUserID == ownerUserID {
			out = append(out, mapBoardRow(row))
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].UpdatedAt.After(out[j].UpdatedAt) })
	return out, nil
}

func (r *KanbanRepository) GetBoard(ctx context.Context, ownerUserID, boardID string) (kanban.BoardDetails, error) {
	boardRow, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.BoardDetails{}, err
	}

	columns, err := r.listColumns(ctx)
	if err != nil {
		return kanban.BoardDetails{}, err
	}
	tasks, err := r.listTasks(ctx)
	if err != nil {
		return kanban.BoardDetails{}, err
	}

	colRows := make([]columnRow, 0)
	for _, col := range columns {
		if col.BoardID == boardID {
			colRows = append(colRows, col)
		}
	}
	sort.Slice(colRows, func(i, j int) bool { return colRows[i].Position < colRows[j].Position })

	columnsOut := make([]kanban.Column, 0, len(colRows))
	columnPositionByID := make(map[string]int, len(colRows))
	for _, col := range colRows {
		columnPositionByID[col.ID] = col.Position
		columnsOut = append(columnsOut, mapColumnRow(col))
	}

	taskRows := make([]taskRow, 0)
	for _, td := range tasks {
		if td.BoardID == boardID {
			taskRows = append(taskRows, td)
		}
	}
	sort.Slice(taskRows, func(i, j int) bool {
		if taskRows[i].ColumnID == taskRows[j].ColumnID {
			return taskRows[i].Position < taskRows[j].Position
		}
		leftPos, leftOK := columnPositionByID[taskRows[i].ColumnID]
		rightPos, rightOK := columnPositionByID[taskRows[j].ColumnID]
		if leftOK && rightOK && leftPos != rightPos {
			return leftPos < rightPos
		}
		if leftOK != rightOK {
			return leftOK
		}
		return taskRows[i].ColumnID < taskRows[j].ColumnID
	})

	todosOut := make([]kanban.Task, 0, len(taskRows))
	for _, td := range taskRows {
		todosOut = append(todosOut, mapTaskRow(td))
	}

	return kanban.BoardDetails{Board: mapBoardRow(boardRow), Columns: columnsOut, Tasks: todosOut}, nil
}

func (r *KanbanRepository) CreateBoardIfAbsent(ctx context.Context, ownerUserID, title string) (kanban.Board, error) {
	// Appwrite atomicity relies on uniqueness for ownerUserId in storage.
	now := time.Now().UTC()
	rowID := uuid.NewString()
	payload := map[string]any{
		"rowId": rowID,
		"data": map[string]any{
			"ownerUserId":  ownerUserID,
			"title":        title,
			"boardVersion": 1,
			"createdAt":    now.Format(time.RFC3339),
			"updatedAt":    now.Format(time.RFC3339),
		},
	}

	if err := r.createRow(ctx, r.boards, payload, nil); err != nil {
		return kanban.Board{}, err
	}

	row, err := r.getBoardRow(ctx, rowID)
	if err != nil {
		return kanban.Board{}, err
	}
	return mapBoardRow(row), nil
}

func (r *KanbanRepository) UpdateBoardTitle(ctx context.Context, ownerUserID, boardID, title string) (kanban.Board, error) {
	row, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Board{}, err
	}

	now := time.Now().UTC()
	payload := map[string]any{"data": map[string]any{
		"title":        title,
		"boardVersion": row.BoardVersion + 1,
		"updatedAt":    now.Format(time.RFC3339),
	}}
	if err := r.updateRow(ctx, r.boards, boardID, payload, nil); err != nil {
		return kanban.Board{}, err
	}
	updated, err := r.getBoardRow(ctx, boardID)
	if err != nil {
		return kanban.Board{}, err
	}
	return mapBoardRow(updated), nil
}

func (r *KanbanRepository) DeleteBoard(ctx context.Context, ownerUserID, boardID string) error {
	if _, err := r.getOwnedBoard(ctx, ownerUserID, boardID); err != nil {
		return err
	}

	columns, err := r.listColumns(ctx)
	if err != nil {
		return err
	}
	tasks, err := r.listTasks(ctx)
	if err != nil {
		return err
	}

	for _, td := range tasks {
		if td.BoardID == boardID {
			if err := r.deleteRow(ctx, r.tasks, td.ID); err != nil {
				return err
			}
		}
	}
	for _, col := range columns {
		if col.BoardID == boardID {
			if err := r.deleteRow(ctx, r.columns, col.ID); err != nil {
				return err
			}
		}
	}

	return r.deleteRow(ctx, r.boards, boardID)
}

func (r *KanbanRepository) CreateColumn(ctx context.Context, ownerUserID, boardID, title string) (kanban.Column, kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}

	columns, err := r.listColumns(ctx)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}
	position := 0
	for _, col := range columns {
		if col.BoardID == boardID && col.Position >= position {
			position = col.Position + 1
		}
	}

	now := time.Now().UTC()
	rowID := uuid.NewString()
	payload := map[string]any{"rowId": rowID, "data": map[string]any{
		"boardId":     boardID,
		"ownerUserId": ownerUserID,
		"title":       title,
		"position":    position,
		"createdAt":   now.Format(time.RFC3339),
		"updatedAt":   now.Format(time.RFC3339),
	}}
	if err := r.createRow(ctx, r.columns, payload, nil); err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}

	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}
	column, err := r.getColumnRow(ctx, rowID)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}
	return mapColumnRow(column), mapBoardRow(board), nil
}

func (r *KanbanRepository) UpdateColumnTitle(ctx context.Context, ownerUserID, boardID, columnID, title string) (kanban.Column, kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}
	column, err := r.getOwnedColumn(ctx, ownerUserID, boardID, columnID)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}

	payload := map[string]any{"data": map[string]any{
		"title":     title,
		"updatedAt": time.Now().UTC().Format(time.RFC3339),
	}}
	if err := r.updateRow(ctx, r.columns, columnID, payload, nil); err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}
	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}
	column, err = r.getColumnRow(ctx, columnID)
	if err != nil {
		return kanban.Column{}, kanban.Board{}, err
	}
	return mapColumnRow(column), mapBoardRow(board), nil
}

func (r *KanbanRepository) DeleteColumn(ctx context.Context, ownerUserID, boardID, columnID string) (kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Board{}, err
	}
	column, err := r.getOwnedColumn(ctx, ownerUserID, boardID, columnID)
	if err != nil {
		return kanban.Board{}, err
	}

	if err := r.deleteRow(ctx, r.columns, column.ID); err != nil {
		return kanban.Board{}, err
	}

	if err := r.reindexColumns(ctx, boardID); err != nil {
		return kanban.Board{}, err
	}
	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Board{}, err
	}
	return mapBoardRow(board), nil
}

func (r *KanbanRepository) CreateTask(ctx context.Context, ownerUserID, boardID, columnID, title, description string) (kanban.Task, kanban.Board, error) {
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
	for _, td := range tasks {
		if td.ColumnID == columnID && td.Position >= position {
			position = td.Position + 1
		}
	}

	now := time.Now().UTC()
	rowID := uuid.NewString()
	payload := map[string]any{"rowId": rowID, "data": map[string]any{
		"boardId":     boardID,
		"columnId":    columnID,
		"ownerUserId": ownerUserID,
		"title":       title,
		"description": description,
		"position":    position,
		"createdAt":   now.Format(time.RFC3339),
		"updatedAt":   now.Format(time.RFC3339),
	}}
	if err := r.createRow(ctx, r.tasks, payload, nil); err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	task, err := r.getTaskRow(ctx, rowID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	return mapTaskRow(task), mapBoardRow(board), nil
}

func (r *KanbanRepository) UpdateTask(ctx context.Context, ownerUserID, boardID, taskID, title, description string) (kanban.Task, kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	if _, err := r.getOwnedTask(ctx, ownerUserID, boardID, taskID); err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}

	payload := map[string]any{"data": map[string]any{
		"title":       title,
		"description": description,
		"updatedAt":   time.Now().UTC().Format(time.RFC3339),
	}}
	if err := r.updateRow(ctx, r.tasks, taskID, payload, nil); err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	task, err := r.getTaskRow(ctx, taskID)
	if err != nil {
		return kanban.Task{}, kanban.Board{}, err
	}
	return mapTaskRow(task), mapBoardRow(board), nil
}

func (r *KanbanRepository) DeleteTask(ctx context.Context, ownerUserID, boardID, taskID string) (kanban.Board, error) {
	board, err := r.getOwnedBoard(ctx, ownerUserID, boardID)
	if err != nil {
		return kanban.Board{}, err
	}
	task, err := r.getOwnedTask(ctx, ownerUserID, boardID, taskID)
	if err != nil {
		return kanban.Board{}, err
	}

	if err := r.deleteRow(ctx, r.tasks, task.ID); err != nil {
		return kanban.Board{}, err
	}
	if err := r.reindexTasks(ctx, task.ColumnID); err != nil {
		return kanban.Board{}, err
	}
	board, err = r.bumpBoard(ctx, board)
	if err != nil {
		return kanban.Board{}, err
	}
	return mapBoardRow(board), nil
}

func (r *KanbanRepository) getOwnedBoard(ctx context.Context, ownerUserID, boardID string) (boardRow, error) {
	row, err := r.getBoardRow(ctx, boardID)
	if err != nil {
		return boardRow{}, err
	}
	if row.OwnerUserID != ownerUserID {
		return boardRow{}, kanban.ErrForbidden
	}
	return row, nil
}

func (r *KanbanRepository) getOwnedColumn(ctx context.Context, ownerUserID, boardID, columnID string) (columnRow, error) {
	row, err := r.getColumnRow(ctx, columnID)
	if err != nil {
		return columnRow{}, err
	}
	if row.BoardID != boardID {
		return columnRow{}, kanban.ErrNotFound
	}
	if row.OwnerUserID != ownerUserID {
		return columnRow{}, kanban.ErrForbidden
	}
	return row, nil
}

func (r *KanbanRepository) getOwnedTask(ctx context.Context, ownerUserID, boardID, taskID string) (taskRow, error) {
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
	return row, nil
}

func (r *KanbanRepository) bumpBoard(ctx context.Context, board boardRow) (boardRow, error) {
	payload := map[string]any{"data": map[string]any{
		"boardVersion": board.BoardVersion + 1,
		"updatedAt":    time.Now().UTC().Format(time.RFC3339),
	}}
	if err := r.updateRow(ctx, r.boards, board.ID, payload, nil); err != nil {
		return boardRow{}, err
	}
	return r.getBoardRow(ctx, board.ID)
}

func (r *KanbanRepository) reindexColumns(ctx context.Context, boardID string) error {
	rows, err := r.listColumns(ctx)
	if err != nil {
		return err
	}
	filtered := make([]columnRow, 0)
	for _, row := range rows {
		if row.BoardID == boardID {
			filtered = append(filtered, row)
		}
	}
	sort.Slice(filtered, func(i, j int) bool { return filtered[i].Position < filtered[j].Position })
	now := time.Now().UTC().Format(time.RFC3339)
	for i, row := range filtered {
		if row.Position == i {
			continue
		}
		payload := map[string]any{"data": map[string]any{"position": i, "updatedAt": now}}
		if err := r.updateRow(ctx, r.columns, row.ID, payload, nil); err != nil {
			return err
		}
	}
	return nil
}

func (r *KanbanRepository) reindexTasks(ctx context.Context, columnID string) error {
	rows, err := r.listTasks(ctx)
	if err != nil {
		return err
	}
	filtered := make([]taskRow, 0)
	for _, row := range rows {
		if row.ColumnID == columnID {
			filtered = append(filtered, row)
		}
	}
	sort.Slice(filtered, func(i, j int) bool { return filtered[i].Position < filtered[j].Position })
	now := time.Now().UTC().Format(time.RFC3339)
	for i, row := range filtered {
		if row.Position == i {
			continue
		}
		payload := map[string]any{"data": map[string]any{"position": i, "updatedAt": now}}
		if err := r.updateRow(ctx, r.tasks, row.ID, payload, nil); err != nil {
			return err
		}
	}
	return nil
}

func (r *KanbanRepository) listBoards(ctx context.Context) ([]boardRow, error) {
	path := fmt.Sprintf("/tablesdb/%s/tables/%s/rows", r.database, r.boards)
	return listRows[boardRow](ctx, r.client, path)
}

func (r *KanbanRepository) listColumns(ctx context.Context) ([]columnRow, error) {
	path := fmt.Sprintf("/tablesdb/%s/tables/%s/rows", r.database, r.columns)
	return listRows[columnRow](ctx, r.client, path)
}

func (r *KanbanRepository) listTasks(ctx context.Context) ([]taskRow, error) {
	path := fmt.Sprintf("/tablesdb/%s/tables/%s/rows", r.database, r.tasks)
	return listRows[taskRow](ctx, r.client, path)
}

func listRows[T any](ctx context.Context, client *Client, path string) ([]T, error) {
	all := make([]T, 0)
	for offset, page := 0, 0; ; offset, page = offset+kanbanListRowsPageLimit, page+1 {
		if page > 1000 {
			return nil, fmt.Errorf("list rows exceeded safety page limit")
		}

		var response listRowsResponse[T]
		if err := client.doServerJSON(ctx, "GET", withRowListQueries(path, offset), nil, &response); err != nil {
			return nil, mapAppwriteError(err)
		}

		all = append(all, response.Rows...)
		if shouldStopRowPaging(len(response.Rows), len(all), response.Total) {
			return all, nil
		}
	}
}

func withRowListQueries(path string, offset int) string {
	values := url.Values{}
	values.Add("limit", strconv.Itoa(kanbanListRowsPageLimit))
	values.Add("offset", strconv.Itoa(offset))
	return path + "?" + values.Encode()
}

func shouldStopRowPaging(pageCount, accumulatedCount, total int) bool {
	if pageCount < kanbanListRowsPageLimit {
		return true
	}
	if total > 0 && accumulatedCount >= total {
		return true
	}
	return false
}

func (r *KanbanRepository) getBoardRow(ctx context.Context, id string) (boardRow, error) {
	var row boardRow
	if err := r.getRow(ctx, r.boards, id, &row); err != nil {
		return boardRow{}, err
	}
	return row, nil
}

func (r *KanbanRepository) getColumnRow(ctx context.Context, id string) (columnRow, error) {
	var row columnRow
	if err := r.getRow(ctx, r.columns, id, &row); err != nil {
		return columnRow{}, err
	}
	return row, nil
}

func (r *KanbanRepository) getTaskRow(ctx context.Context, id string) (taskRow, error) {
	var row taskRow
	if err := r.getRow(ctx, r.tasks, id, &row); err != nil {
		return taskRow{}, err
	}
	return row, nil
}

func (r *KanbanRepository) createRow(ctx context.Context, table string, payload map[string]any, out any) error {
	path := fmt.Sprintf("/tablesdb/%s/tables/%s/rows", r.database, table)
	if err := r.client.doServerJSON(ctx, "POST", path, payload, out); err != nil {
		return mapAppwriteError(err)
	}
	return nil
}

func (r *KanbanRepository) updateRow(ctx context.Context, table, rowID string, payload map[string]any, out any) error {
	path := fmt.Sprintf("/tablesdb/%s/tables/%s/rows/%s", r.database, table, rowID)
	if err := r.client.doServerJSON(ctx, "PATCH", path, payload, out); err != nil {
		return mapAppwriteError(err)
	}
	return nil
}

func (r *KanbanRepository) getRow(ctx context.Context, table, rowID string, out any) error {
	path := fmt.Sprintf("/tablesdb/%s/tables/%s/rows/%s", r.database, table, rowID)
	if err := r.client.doServerJSON(ctx, "GET", path, nil, out); err != nil {
		return mapAppwriteError(err)
	}
	return nil
}

func (r *KanbanRepository) deleteRow(ctx context.Context, table, rowID string) error {
	path := fmt.Sprintf("/tablesdb/%s/tables/%s/rows/%s", r.database, table, rowID)
	if err := r.client.doServerJSON(ctx, "DELETE", path, nil, nil); err != nil {
		return mapAppwriteError(err)
	}
	return nil
}

func mapAppwriteError(err error) error {
	if err == nil {
		return nil
	}
	if isStatus(err, 404) {
		return kanban.ErrNotFound
	}
	if isStatus(err, 409) {
		return kanban.ErrConflict
	}
	if isStatus(err, 400) {
		return fmt.Errorf("%w: %v", kanban.ErrInvalidInput, err)
	}
	if isStatus(err, 401) || isStatus(err, 403) {
		return kanban.ErrForbidden
	}
	return err
}

func mapBoardRow(row boardRow) kanban.Board {
	return kanban.Board{ID: row.ID, OwnerUserID: row.OwnerUserID, Title: row.Title, BoardVersion: row.BoardVersion, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt}
}

func mapColumnRow(row columnRow) kanban.Column {
	return kanban.Column{ID: row.ID, BoardID: row.BoardID, OwnerUserID: row.OwnerUserID, Title: row.Title, Position: row.Position, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt}
}

func mapTaskRow(row taskRow) kanban.Task {
	return kanban.Task{ID: row.ID, BoardID: row.BoardID, ColumnID: row.ColumnID, OwnerUserID: row.OwnerUserID, Title: row.Title, Description: row.Description, Position: row.Position, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt}
}
