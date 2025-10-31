package stocks

import "strings"

// ToProviderSymbol แปลงรูปแบบสัญลักษณ์ตามตลาด/ผู้ให้บริการ
func ToProviderSymbol(exchange, symbol string) string {
	switch exchangeUpper := strings.ToUpper(exchange); exchangeUpper {
	case "SET":
		return strings.ToUpper(symbol) + ".BK"
	default:
		return strings.ToUpper(symbol)
	}
}
