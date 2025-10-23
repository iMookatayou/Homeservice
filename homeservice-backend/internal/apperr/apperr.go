package apperr

import "net/http"

type AppError struct {
	Code    string 
	Message string 
	Status  int
}

func (e *AppError) Error() string { return e.Message }

var (
	ErrBadRequest   = &AppError{Code: "BAD_REQUEST", Message: "bad request", Status: http.StatusBadRequest}
	ErrUnauthorized = &AppError{Code: "UNAUTHORIZED", Message: "unauthorized", Status: http.StatusUnauthorized}
	ErrForbidden    = &AppError{Code: "FORBIDDEN", Message: "forbidden", Status: http.StatusForbidden}
	ErrNotFound     = &AppError{Code: "NOT_FOUND", Message: "not found", Status: http.StatusNotFound}
	ErrConflict     = &AppError{Code: "CONFLICT", Message: "conflict", Status: http.StatusConflict}
	ErrInternal     = &AppError{Code: "INTERNAL", Message: "internal error", Status: http.StatusInternalServerError}
)
