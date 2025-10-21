package httputil

import (
	"net/http"

	"github.com/yourname/homeservice-backend/internal/apperr"
)

func FromError(w http.ResponseWriter, err error, traceID string) {
	if e, ok := err.(*apperr.AppError); ok {
		Error(w, e.Status, e.Code, e.Message, traceID)
		return
	}
	Error(w, http.StatusInternalServerError, apperr.ErrInternal.Code, apperr.ErrInternal.Message, traceID)
}
