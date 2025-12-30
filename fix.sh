#!/bin/bash

set -e

echo "🔧 Setting up API Gateway clients for all services..."

SERVICES=(
  "users-service"
  "orders-service"
  "payments-service"
  "delivery-service"
)

for SERVICE in "${SERVICES[@]}"; do
  CLIENT_DIR="./$SERVICE/internal/clients"
  mkdir -p "$CLIENT_DIR"
done

# =========================================================
# USERS → ORDERS
# =========================================================
cat > users-service/internal/clients/orders_client.go << 'EOF'
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
EOF

# =========================================================
# ORDERS → USERS
# =========================================================
cat > orders-service/internal/clients/users_client.go << 'EOF'
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
EOF

# =========================================================
# PAYMENTS → USERS
# =========================================================
cat > payments-service/internal/clients/users_client.go << 'EOF'
package clients

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

func CheckUser(userID int64) error {
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
		return fmt.Errorf("user not found, status %d", resp.StatusCode)
	}

	return nil
}
EOF

# =========================================================
# DELIVERY → USERS
# =========================================================
cat > delivery-service/internal/clients/users_client.go << 'EOF'
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
EOF

echo "✅ All services are now configured to communicate via API Gateway"
