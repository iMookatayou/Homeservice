package httpx

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"github.com/go-playground/validator/v10"
)

// ตัว validator ใช้เป็น global ได้ ปลอดภัยสำหรับ concurrent
var validate = validator.New(validator.WithRequiredStructEnabled())

// BindJSON แปลง JSON -> struct และ reject ฟิลด์แปลก ๆ
func BindJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()

	if err := dec.Decode(dst); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}
	// ป้องกันกรณี body มีข้อมูลเกิน 1 JSON object
	if dec.More() {
		return errors.New("invalid JSON: multiple objects")
	}

	// validate struct tags e.g. `validate:"required,min=1"`
	if err := validate.Struct(dst); err != nil {
		return err
	}
	return nil
}

// ValidationErrors แปลง error จาก validator เป็น map[field]message อ่านง่าย
func ValidationErrors(err error) map[string]string {
	out := map[string]string{}
	if err == nil {
		return out
	}
	var verrs validator.ValidationErrors
	if errors.As(err, &verrs) {
		for _, fe := range verrs {
			// ชื่อฟิลด์แบบ json (ถ้าตั้ง tag json ไว้)
			name := fe.Field()
			if jsonTag := fe.StructField(); jsonTag != "" {
				name = fe.Field() // ปรับตามต้องการถ้าอยาก map กับ tag `json`
			}
			switch fe.Tag() {
			case "required":
				out[name] = "is required"
			case "min":
				out[name] = "is too short"
			case "max":
				out[name] = "is too long"
			case "oneof":
				out[name] = "has invalid value"
			default:
				out[name] = "is invalid"
			}
		}
	} else {
		out["_"] = err.Error()
	}
	return out
}

// WriteJSONError ช่วยเขียน error response มาตรฐาน
func WriteJSONError(w http.ResponseWriter, status int, msg string, fields map[string]string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	type errBody struct {
		Error  string            `json:"error"`
		Fields map[string]string `json:"fields,omitempty"`
	}
	_ = json.NewEncoder(w).Encode(errBody{
		Error:  msg,
		Fields: fields,
	})
}
