package medicine

import "errors"

var (
	ErrForbidden = errors.New("forbidden")
	ErrNotFound  = errors.New("not_found")
	ErrConflict  = errors.New("conflict")
	ErrBadInput  = errors.New("bad_input")
	ErrNoStock   = errors.New("no_stock")
)
