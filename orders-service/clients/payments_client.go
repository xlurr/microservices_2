package clients

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

type PaymentRequest struct {
	OrderID       int64   `json:"order_id"`
	Amount        float64 `json:"amount"`
	Status        string  `json:"status"`
	PaymentMethod string  `json:"payment_method"`
}

func CreatePayment(req PaymentRequest) error {
	baseURL := os.Getenv("PAYMENTS_SERVICE_URL")
	if baseURL == "" {
		return fmt.Errorf("PAYMENTS_SERVICE_URL not set")
	}

	body, _ := json.Marshal(req)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(
		baseURL+"/payments",
		"application/json",
		bytes.NewBuffer(body),
	)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("payments-service returned %d", resp.StatusCode)
	}

	return nil
}
