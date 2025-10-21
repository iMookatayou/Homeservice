package httputil

import (
	"encoding/json"
	"net/http"
)

type Envelope struct {
	Status  string      `json:"status"`          // "success" | "error"
	Data    interface{} `json:"data,omitempty"`  // payload
	Error   *ErrResp    `json:"error,omitempty"` // normalized error
	Message string      `json:"message,omitempty"`
}

type ErrResp struct {
	Code    string `json:"code"`   // e.g. "BAD_REQUEST", "NOT_FOUND"
	Detail  string `json:"detail"` // human msg (safe to show UI)
	TraceID string `json:"trace_id,omitempty"`
}

func JSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func OK(w http.ResponseWriter, data interface{}) {
	JSON(w, http.StatusOK, Envelope{Status: "success", Data: data})
}

func Created(w http.ResponseWriter, data interface{}) {
	JSON(w, http.StatusCreated, Envelope{Status: "success", Data: data})
}

func Error(w http.ResponseWriter, status int, code, detail, traceID string) {
	JSON(w, status, Envelope{
		Status: "error",
		Error:  &ErrResp{Code: code, Detail: detail, TraceID: traceID},
	})
}
