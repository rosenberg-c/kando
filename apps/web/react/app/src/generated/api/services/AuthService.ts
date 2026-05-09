/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { AuthBrowserTokens } from '../models/AuthBrowserTokens';
import type { AuthLoginRequest } from '../models/AuthLoginRequest';
import type { AuthRefreshRequest } from '../models/AuthRefreshRequest';
import type { AuthTokens } from '../models/AuthTokens';
import type { ErrorModel } from '../models/ErrorModel';
import type { CancelablePromise } from '../core/CancelablePromise';
import { OpenAPI } from '../core/OpenAPI';
import { request as __request } from '../core/request';
export class AuthService {
    /**
     * Authenticates a user, returns tokens, and sets browser auth cookies
     * @returns AuthBrowserTokens OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static login({
        requestBody,
        secFetchSite,
        origin,
    }: {
        requestBody: AuthLoginRequest,
        secFetchSite?: string,
        origin?: string,
    }): CancelablePromise<AuthBrowserTokens | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/login',
            headers: {
                'Sec-Fetch-Site': secFetchSite,
                'Origin': origin,
            },
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Revokes session and clears browser auth cookies
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static logout({
        cookie,
        secFetchSite,
        origin,
    }: {
        cookie?: string,
        secFetchSite?: string,
        origin?: string,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/logout',
            headers: {
                'Cookie': cookie,
                'Sec-Fetch-Site': secFetchSite,
                'Origin': origin,
            },
        });
    }
    /**
     * Authenticates a native client and returns tokens
     * @returns AuthTokens OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static nativeLogin({
        requestBody,
    }: {
        requestBody: AuthLoginRequest,
    }): CancelablePromise<AuthTokens | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/native/login',
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Revokes session for native client
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static nativeLogout({
        requestBody,
    }: {
        requestBody: AuthRefreshRequest,
    }): CancelablePromise<ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/native/logout',
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Refreshes an access token for native client
     * @returns AuthTokens OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static nativeRefreshAuth({
        requestBody,
    }: {
        requestBody: AuthRefreshRequest,
    }): CancelablePromise<AuthTokens | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/native/refresh',
            body: requestBody,
            mediaType: 'application/json',
        });
    }
    /**
     * Refreshes an access token using browser auth cookies
     * @returns AuthBrowserTokens OK
     * @returns ErrorModel Error
     * @throws ApiError
     */
    public static refreshAuth({
        cookie,
        secFetchSite,
        origin,
    }: {
        cookie?: string,
        secFetchSite?: string,
        origin?: string,
    }): CancelablePromise<AuthBrowserTokens | ErrorModel> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/auth/refresh',
            headers: {
                'Cookie': cookie,
                'Sec-Fetch-Site': secFetchSite,
                'Origin': origin,
            },
        });
    }
}
