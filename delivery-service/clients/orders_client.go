package clients

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

func UpdateOrderDeliveryStatus(orderID int64, status string) error {
	baseURL := os.Getenv("ORDERS_SERVICE_URL")
	if baseURL == "" {
		return fmt.Errorf("ORDERS_SERVICE_URL not set")
	}

	payload := map[string]string{"status": status}
	body, _ := json.Marshal(payload)

	req, err := http.NewRequest(
		http.MethodPut,
		fmt.Sprintf("%s/orders/%d", baseURL, orderID),
		bytes.NewBuffer(body),
	)
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("orders-service returned %d", resp.StatusCode)
	}

	return nil
}
