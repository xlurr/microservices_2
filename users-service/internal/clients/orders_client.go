package clients

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

// DeleteUserOrders удаляет все заказы пользователя через API Gateway
func DeleteUserOrders(userID int64) error {
	gateway := os.Getenv("GATEWAY_URL")
	if gateway == "" {
		return fmt.Errorf("GATEWAY_URL not set")
	}

	url := fmt.Sprintf("%s/api/orders/user/%d", gateway, userID)

	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest(http.MethodDelete, url, nil)
	if err != nil {
		return err
	}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("gateway returned %d", resp.StatusCode)
	}

	return nil
}
