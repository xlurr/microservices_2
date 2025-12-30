package clients

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

// DeleteUserOrders удаляет все заказы пользователя
func DeleteUserOrders(userID int64) error {
	baseURL := os.Getenv("ORDERS_SERVICE_URL")
	if baseURL == "" {
		return fmt.Errorf("ORDERS_SERVICE_URL not set")
	}

	url := fmt.Sprintf("%s/orders/user/%d", baseURL, userID)

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	req, err := http.NewRequest(http.MethodDelete, url, nil)
	if err != nil {
		return err
	}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		return fmt.Errorf("orders-service returned status %d", resp.StatusCode)
	}

	return nil
}
