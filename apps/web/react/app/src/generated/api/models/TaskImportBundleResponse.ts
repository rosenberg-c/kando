/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { TaskImportBundleBoardResult } from './TaskImportBundleBoardResult';
export type TaskImportBundleResponse = {
    /**
     * A URL to the JSON Schema for this object.
     */
    readonly $schema?: string;
    results: Array<TaskImportBundleBoardResult>;
    totalCreatedColumnCount: number;
    totalImportedTaskCount: number;
};

