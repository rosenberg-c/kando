/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { TaskExportBundleBoard } from './TaskExportBundleBoard';
export type TaskExportBundle = {
    /**
     * A URL to the JSON Schema for this object.
     */
    readonly $schema?: string;
    boards: Array<TaskExportBundleBoard>;
    exportedAt: string;
    formatVersion: number;
};

