package stocks

import "strings"

// ToProviderSymbol
func ToProviderSymbol(exchange, symbol string) string {
	switch exchangeUpper := strings.ToUpper(exchange); exchangeUpper {
	case "SET":
		return strings.ToUpper(symbol) + ".BK"
	default:
		return strings.ToUpper(symbol)
	}
}
