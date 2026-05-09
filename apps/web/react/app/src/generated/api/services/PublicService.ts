/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { ErrorModel } from '../models/ErrorModel';
import type { MeResponse } from '../models/MeResponse';
import type { CancelablePromise } from '../core/CancelablePromise';
import { OpenAPI } from '../core/OpenAPI';
import { request as __request } from '../core/request';
export class PublicService {
    /**
     * Returns hello world text
     * @returns string Plain text hello message
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static getHello(): CancelablePromise<string | ErrorModel> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/hello',
        });
    }
    /**
     * Returns the authenticated user identity
     * @returns MeResponse OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static getMe({
        authorization,
        cookie,
        secFetchSite,
        origin,
    }: {
        authorization?: string,
        cookie?: string,
        secFetchSite?: string,
        origin?: string,
    }): CancelablePromise<MeResponse | ErrorModel> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/me',
            headers: {
                'Authorization': authorization,
                'Cookie': cookie,
                'Sec-Fetch-Site': secFetchSite,
                'Origin': origin,
            },
        });
    }
}
