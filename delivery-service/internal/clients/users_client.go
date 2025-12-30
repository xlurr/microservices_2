package clients

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

func ValidateUser(userID int64) error {
	gateway := os.Getenv("GATEWAY_URL")
	if gateway == "" {
		return fmt.Errorf("GATEWAY_URL not set")
	}

	url := fmt.Sprintf("%s/api/users/%d", gateway, userID)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("invalid user, status %d", resp.StatusCode)
	}

	return nil
}
