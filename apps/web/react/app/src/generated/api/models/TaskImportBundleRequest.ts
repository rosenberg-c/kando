/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { TaskExportBundle } from './TaskExportBundle';
export type TaskImportBundleRequest = {
    /**
     * A URL to the JSON Schema for this object.
     */
    readonly $schema?: string;
    bundle: TaskExportBundle;
    sourceBoardIds: Array<string>;
};

