/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { AuthLoginRequest } from '../models/AuthLoginRequest';
import type { AuthRefreshRequest } from '../models/AuthRefreshRequest';
import type { AuthTokens } from '../models/AuthTokens';
import type { ErrorModel } from '../models/ErrorModel';
import type { CancelablePromise } from '../core/CancelablePromise';
import { OpenAPI } from '../core/OpenAPI';
import { request as __request } from '../core/request';
export class AuthService {
    /**
     * Authenticates a user and returns tokens
     * @returns AuthTokens OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static login({
        requestBody,
    }: {
        requestBody: AuthLoginRequest,
    }): CancelablePromise<AuthTokens | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/login',
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Revokes session and logs out user
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static logout({
        requestBody,
    }: {
        requestBody: AuthRefreshRequest,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/logout',
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Refreshes an access token using refresh token
     * @returns AuthTokens OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static refreshAuth({
        requestBody,
    }: {
        requestBody: AuthRefreshRequest,
    }): CancelablePromise<AuthTokens | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/refresh',
            body: requestBody,
            mediaType: 'application/json',
        });
    }
}
