/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { TaskColumnOrderRequest } from './TaskColumnOrderRequest';
export type ReorderTasksRequest = {
    /**
     * A URL to the JSON Schema for this object.
     */
    readonly $schema?: string;
    columns: Array<TaskColumnOrderRequest>;
};

