/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { Board } from './Board';
import type { Column } from './Column';
import type { Task } from './Task';
export type BoardDetailsResponse = {
    /**
     * A URL to the JSON Schema for this object.
     */
    readonly $schema?: string;
    board: Board;
    columns: Array<Column> | null;
    tasks: Array<Task> | null;
};

