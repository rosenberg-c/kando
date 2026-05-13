import { ApiError } from "../generated/api";

export function mapApiError<T>(error: unknown, onApiError: (apiError: ApiError) => T): T {
  if (error instanceof ApiError) {
    return onApiError(error);
  }

  throw error;
}
