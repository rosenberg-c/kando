/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { ArchiveColumnTasksResponse } from '../models/ArchiveColumnTasksResponse';
import type { ArchivedTask } from '../models/ArchivedTask';
import type { Board } from '../models/Board';
import type { BoardDetailsResponse } from '../models/BoardDetailsResponse';
import type { Column } from '../models/Column';
import type { CreateBoardRequest } from '../models/CreateBoardRequest';
import type { CreateColumnRequest } from '../models/CreateColumnRequest';
import type { CreateTaskRequest } from '../models/CreateTaskRequest';
import type { ErrorModel } from '../models/ErrorModel';
import type { ReorderColumnsRequest } from '../models/ReorderColumnsRequest';
import type { ReorderTasksRequest } from '../models/ReorderTasksRequest';
import type { RestoreBoardRequest } from '../models/RestoreBoardRequest';
import type { Task } from '../models/Task';
import type { TaskBatchMutationRequest } from '../models/TaskBatchMutationRequest';
import type { TaskExportBundle } from '../models/TaskExportBundle';
import type { TaskExportBundleRequest } from '../models/TaskExportBundleRequest';
import type { TaskImportBundleRequest } from '../models/TaskImportBundleRequest';
import type { TaskImportBundleResponse } from '../models/TaskImportBundleResponse';
import type { UpdateBoardRequest } from '../models/UpdateBoardRequest';
import type { UpdateColumnRequest } from '../models/UpdateColumnRequest';
import type { UpdateTaskRequest } from '../models/UpdateTaskRequest';
import type { CancelablePromise } from '../core/CancelablePromise';
import { OpenAPI } from '../core/OpenAPI';
import { request as __request } from '../core/request';
export class BoardsService {
    /**
     * List boards for the authenticated user
     * @returns Board OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static listBoards({
        authorization,
    }: {
        authorization?: string,
    }): CancelablePromise<Array<Board> | null | ErrorModel> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/boards',
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Create a board
     * @returns Board OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static createBoard({
        requestBody,
        authorization,
    }: {
        requestBody: CreateBoardRequest,
        authorization?: string,
    }): CancelablePromise<Board | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards',
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * List archived boards for the authenticated user
     * @returns Board OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static listArchivedBoards({
        authorization,
    }: {
        authorization?: string,
    }): CancelablePromise<Array<Board> | null | ErrorModel> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/boards/archived',
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Export selected boards as a multi-board task bundle
     * @returns TaskExportBundle OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static exportTasksBundle({
        requestBody,
        authorization,
    }: {
        requestBody: TaskExportBundleRequest,
        authorization?: string,
    }): CancelablePromise<TaskExportBundle | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/tasks/export',
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Import selected snapshots from a multi-board task bundle
     * @returns TaskImportBundleResponse OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static importTasksBundle({
        requestBody,
        authorization,
    }: {
        requestBody: TaskImportBundleRequest,
        authorization?: string,
    }): CancelablePromise<TaskImportBundleResponse | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/tasks/import',
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Delete a board
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static deleteBoard({
        boardId,
        authorization,
    }: {
        boardId: string,
        authorization?: string,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'DELETE',
            url: '/boards/{boardId}',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Get board with columns and tasks
     * @returns BoardDetailsResponse OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static getBoard({
        boardId,
        authorization,
    }: {
        boardId: string,
        authorization?: string,
    }): CancelablePromise<BoardDetailsResponse | ErrorModel> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/boards/{boardId}',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Update board title
     * @returns Board OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static updateBoard({
        boardId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        requestBody: UpdateBoardRequest,
        authorization?: string,
    }): CancelablePromise<Board | ErrorModel> {
        return __request(OpenAPI, {
            method: 'PATCH',
            url: '/boards/{boardId}',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Permanently delete an archived board
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static deleteArchivedBoard({
        boardId,
        authorization,
    }: {
        boardId: string,
        authorization?: string,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'DELETE',
            url: '/boards/{boardId}/archive',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Archive a board
     * @returns Board OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static archiveBoard({
        boardId,
        authorization,
    }: {
        boardId: string,
        authorization?: string,
    }): CancelablePromise<Board | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/{boardId}/archive',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Create a column
     * @returns Column OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static createColumn({
        boardId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        requestBody: CreateColumnRequest,
        authorization?: string,
    }): CancelablePromise<Column | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/{boardId}/columns',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Replace board column order
     * @returns Column OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static reorderColumns({
        boardId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        requestBody: ReorderColumnsRequest,
        authorization?: string,
    }): CancelablePromise<Array<Column> | null | ErrorModel> {
        return __request(OpenAPI, {
            method: 'PUT',
            url: '/boards/{boardId}/columns/order',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Delete a column
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static deleteColumn({
        boardId,
        columnId,
        authorization,
    }: {
        boardId: string,
        columnId: string,
        authorization?: string,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'DELETE',
            url: '/boards/{boardId}/columns/{columnId}',
            path: {
                'boardId': boardId,
                'columnId': columnId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Update column title
     * @returns Column OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static updateColumn({
        boardId,
        columnId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        columnId: string,
        requestBody: UpdateColumnRequest,
        authorization?: string,
    }): CancelablePromise<Column | ErrorModel> {
        return __request(OpenAPI, {
            method: 'PATCH',
            url: '/boards/{boardId}/columns/{columnId}',
            path: {
                'boardId': boardId,
                'columnId': columnId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Archive all active tasks in a column
     * @returns ArchiveColumnTasksResponse OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static archiveTasksInColumn({
        boardId,
        columnId,
        authorization,
    }: {
        boardId: string,
        columnId: string,
        authorization?: string,
    }): CancelablePromise<ArchiveColumnTasksResponse | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/{boardId}/columns/{columnId}/archive-tasks',
            path: {
                'boardId': boardId,
                'columnId': columnId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Restore an archived board
     * @returns Board OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static restoreBoard({
        boardId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        requestBody: RestoreBoardRequest,
        authorization?: string,
    }): CancelablePromise<Board | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/{boardId}/restore',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Create a task
     * @returns Task OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static createTask({
        boardId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        requestBody: CreateTaskRequest,
        authorization?: string,
    }): CancelablePromise<Task | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/{boardId}/tasks',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Apply list-based task batch action
     * @returns Task OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static applyTaskBatchMutation({
        boardId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        requestBody: TaskBatchMutationRequest,
        authorization?: string,
    }): CancelablePromise<Array<Task> | null | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/{boardId}/tasks/actions',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * List archived tasks for a board
     * @returns ArchivedTask OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static listArchivedTasksByBoard({
        boardId,
        authorization,
    }: {
        boardId: string,
        authorization?: string,
    }): CancelablePromise<Array<ArchivedTask> | null | ErrorModel> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/boards/{boardId}/tasks/archived',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Replace board task order
     * @returns Task OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static reorderTasks({
        boardId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        requestBody: ReorderTasksRequest,
        authorization?: string,
    }): CancelablePromise<Array<Task> | null | ErrorModel> {
        return __request(OpenAPI, {
            method: 'PUT',
            url: '/boards/{boardId}/tasks/order',
            path: {
                'boardId': boardId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Delete a task
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static deleteTask({
        boardId,
        taskId,
        authorization,
    }: {
        boardId: string,
        taskId: string,
        authorization?: string,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'DELETE',
            url: '/boards/{boardId}/tasks/{taskId}',
            path: {
                'boardId': boardId,
                'taskId': taskId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Update a task
     * @returns Task OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static updateTask({
        boardId,
        taskId,
        requestBody,
        authorization,
    }: {
        boardId: string,
        taskId: string,
        requestBody: UpdateTaskRequest,
        authorization?: string,
    }): CancelablePromise<Task | ErrorModel> {
        return __request(OpenAPI, {
            method: 'PATCH',
            url: '/boards/{boardId}/tasks/{taskId}',
            path: {
                'boardId': boardId,
                'taskId': taskId,
            },
            headers: {
                'Authorization': authorization,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Permanently delete an archived task
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static deleteArchivedTask({
        boardId,
        taskId,
        authorization,
    }: {
        boardId: string,
        taskId: string,
        authorization?: string,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'DELETE',
            url: '/boards/{boardId}/tasks/{taskId}/archived',
            path: {
                'boardId': boardId,
                'taskId': taskId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
    /**
     * Restore an archived task
     * @returns Task OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static restoreArchivedTask({
        boardId,
        taskId,
        authorization,
    }: {
        boardId: string,
        taskId: string,
        authorization?: string,
    }): CancelablePromise<Task | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/boards/{boardId}/tasks/{taskId}/restore',
            path: {
                'boardId': boardId,
                'taskId': taskId,
            },
            headers: {
                'Authorization': authorization,
            },
        });
    }
}
