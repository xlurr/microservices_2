package clients

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

type UserExistsResponse struct {
	Exists bool `json:"exists"`
}

func UserExists(userID int64) (bool, error) {
	gateway := os.Getenv("GATEWAY_URL")
	if gateway == "" {
		return false, fmt.Errorf("GATEWAY_URL not set")
	}

	url := fmt.Sprintf("%s/api/users/%d/exists", gateway, userID)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("gateway returned %d", resp.StatusCode)
	}

	var r UserExistsResponse
	if err := json.NewDecoder(resp.Body).Decode(&r); err != nil {
		return false, err
	}

	return r.Exists, nil
}
