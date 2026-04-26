package contracts

import "time"

type AuthLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type AuthRefreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type AuthTokens struct {
	AccessToken          string    `json:"accessToken"`
	RefreshToken         string    `json:"refreshToken"`
	AccessTokenExpiresAt time.Time `json:"accessTokenExpiresAt"`
}

type MeResponse struct {
	UserID string `json:"userId"`
	Email  string `json:"email"`
}

type Board struct {
	ID                    string    `json:"id" format:"uuid"`
	OwnerUserID           string    `json:"ownerUserId"`
	Title                 string    `json:"title" minLength:"1" maxLength:"120"`
	ArchivedOriginalTitle *string   `json:"archivedOriginalTitle,omitempty" maxLength:"120"`
	BoardVersion          int       `json:"boardVersion" minimum:"1"`
	CreatedAt             time.Time `json:"createdAt" format:"date-time"`
	UpdatedAt             time.Time `json:"updatedAt" format:"date-time"`
}

type Column struct {
	ID        string    `json:"id" format:"uuid"`
	BoardID   string    `json:"boardId" format:"uuid"`
	Title     string    `json:"title" minLength:"1" maxLength:"120"`
	Position  int       `json:"position" minimum:"0"`
	CreatedAt time.Time `json:"createdAt" format:"date-time"`
	UpdatedAt time.Time `json:"updatedAt" format:"date-time"`
}

type Task struct {
	ID          string    `json:"id" format:"uuid"`
	BoardID     string    `json:"boardId" format:"uuid"`
	ColumnID    string    `json:"columnId" format:"uuid"`
	Title       string    `json:"title" minLength:"1" maxLength:"200"`
	Description string    `json:"description" maxLength:"4000"`
	Position    int       `json:"position" minimum:"0"`
	CreatedAt   time.Time `json:"createdAt" format:"date-time"`
	UpdatedAt   time.Time `json:"updatedAt" format:"date-time"`
}

type CreateBoardRequest struct {
	Title string `json:"title" minLength:"1" maxLength:"120"`
}

type UpdateBoardRequest struct {
	Title string `json:"title" minLength:"1" maxLength:"120"`
}

type RestoreBoardRequest struct {
	TitleMode string `json:"titleMode" enum:"original,archived"`
}

type BoardDetailsResponse struct {
	Board   Board    `json:"board"`
	Columns []Column `json:"columns"`
	Tasks   []Task   `json:"tasks"`
}

type CreateColumnRequest struct {
	Title string `json:"title" minLength:"1" maxLength:"120"`
}

type UpdateColumnRequest struct {
	Title string `json:"title" minLength:"1" maxLength:"120"`
}

type ReorderColumnsRequest struct {
	ColumnIDs []string `json:"columnIds" minItems:"1" nullable:"false"`
}

type CreateTaskRequest struct {
	ColumnID    string `json:"columnId" format:"uuid"`
	Title       string `json:"title" minLength:"1" maxLength:"200"`
	Description string `json:"description" maxLength:"4000"`
}

type UpdateTaskRequest struct {
	Title       string `json:"title" minLength:"1" maxLength:"200"`
	Description string `json:"description" maxLength:"4000"`
}

type TaskColumnOrderRequest struct {
	ColumnID string   `json:"columnId" format:"uuid"`
	TaskIDs  []string `json:"taskIds" nullable:"false"`
}

type ReorderTasksRequest struct {
	Columns []TaskColumnOrderRequest `json:"columns" minItems:"1" nullable:"false"`
}

type TaskExportPayload struct {
	FormatVersion int                `json:"formatVersion" minimum:"1"`
	BoardTitle    string             `json:"boardTitle" minLength:"1" maxLength:"120"`
	ExportedAt    string             `json:"exportedAt" format:"date-time"`
	Columns       []TaskExportColumn `json:"columns" nullable:"false"`
}

type TaskExportColumn struct {
	Title string           `json:"title" minLength:"1" maxLength:"120"`
	Tasks []TaskExportTask `json:"tasks" nullable:"false"`
}

type TaskExportTask struct {
	Title       string `json:"title" minLength:"1" maxLength:"200"`
	Description string `json:"description" maxLength:"4000"`
}

type TaskImportResponse struct {
	CreatedColumnCount int `json:"createdColumnCount" minimum:"0"`
	ImportedTaskCount  int `json:"importedTaskCount" minimum:"0"`
}

type TaskExportBundle struct {
	FormatVersion int                     `json:"formatVersion" minimum:"1"`
	ExportedAt    string                  `json:"exportedAt" format:"date-time"`
	Boards        []TaskExportBundleBoard `json:"boards" minItems:"1" nullable:"false"`
}

type TaskExportBundleBoard struct {
	SourceBoardID    string            `json:"sourceBoardId" format:"uuid"`
	SourceBoardTitle string            `json:"sourceBoardTitle" minLength:"1" maxLength:"120"`
	Payload          TaskExportPayload `json:"payload"`
}

type TaskExportBundleRequest struct {
	BoardIDs []string `json:"boardIds" minItems:"1" nullable:"false"`
}

type TaskImportBundleRequest struct {
	SourceBoardIDs []string         `json:"sourceBoardIds" minItems:"1" nullable:"false"`
	Bundle         TaskExportBundle `json:"bundle"`
}

type TaskImportBundleBoardResult struct {
	SourceBoardID      string `json:"sourceBoardId" format:"uuid"`
	DestinationBoardID string `json:"destinationBoardId" format:"uuid"`
	CreatedColumnCount int    `json:"createdColumnCount" minimum:"0"`
	ImportedTaskCount  int    `json:"importedTaskCount" minimum:"0"`
}

type TaskImportBundleResponse struct {
	Results                 []TaskImportBundleBoardResult `json:"results" nullable:"false"`
	TotalCreatedColumnCount int                           `json:"totalCreatedColumnCount" minimum:"0"`
	TotalImportedTaskCount  int                           `json:"totalImportedTaskCount" minimum:"0"`
}
