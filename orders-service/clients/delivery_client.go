package clients

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

type DeliveryRequest struct {
	OrderID int64  `json:"order_id"`
	Address string `json:"address"`
	Status  string `json:"status"`
}

func CreateDelivery(req DeliveryRequest) error {
	baseURL := os.Getenv("DELIVERY_SERVICE_URL")
	if baseURL == "" {
		return fmt.Errorf("DELIVERY_SERVICE_URL not set")
	}

	body, _ := json.Marshal(req)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(
		baseURL+"/deliveries",
		"application/json",
		bytes.NewBuffer(body),
	)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("delivery-service returned %d", resp.StatusCode)
	}

	return nil
}
