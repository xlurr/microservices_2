#!/bin/bash
set -e

echo "🔧 Обновление всех сервисов с Swagger аннотациями..."
echo ""

# ============ USERS SERVICE ============
echo "📝 Обновляю users-service..."
cat > users-service/cmd/main.go << 'EOFGO'
package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	httpSwagger "github.com/swaggo/http-swagger"
	_ "users-service/docs"
)

var db *sql.DB

type User struct {
	ID        int    `json:"id"`
	Email     string `json:"email" validate:"required,email"`
	Name      string `json:"name" validate:"required,min=2,max=100"`
	Age       int    `json:"age" validate:"required,min=1,max=150"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
}

// @title Users Service API
// @version 1.0
// @description Микросервис управления пользователями
// @host localhost:8001
// @BasePath /
func main() {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	var err error
	db, err = sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatalf("DB connection error: %v", err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatalf("DB ping error: %v", err)
	}
	log.Printf("✅ Connected to PostgreSQL (users-service)")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8001"
	}

	router := mux.NewRouter()
	router.HandleFunc("/health", healthCheck).Methods("GET")
	router.HandleFunc("/users", getUsers).Methods("GET")
	router.HandleFunc("/users/{id}", getUser).Methods("GET")
	router.HandleFunc("/users", createUser).Methods("POST")
	router.HandleFunc("/users/{id}", updateUser).Methods("PUT")
	router.HandleFunc("/users/{id}", deleteUser).Methods("DELETE")
	
	router.PathPrefix("/swagger/").Handler(httpSwagger.WrapHandler)

	log.Printf("🚀 Users Service started on port %s", port)
	log.Printf("📚 Swagger UI: http://localhost:%s/swagger/index.html", port)
	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

// @Summary Health check
// @Description Проверка состояния сервиса
// @Tags health
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

// @Summary Get all users
// @Description Получить список всех пользователей
// @Tags users
// @Produce json
// @Success 200 {array} User
// @Router /users [get]
func getUsers(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, email, name, age, created_at, updated_at FROM users ORDER BY id LIMIT 100")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Email, &u.Name, &u.Age, &u.CreatedAt, &u.UpdatedAt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		users = append(users, u)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

// @Summary Get user by ID
// @Description Получить пользователя по ID
// @Tags users
// @Produce json
// @Param id path int true "User ID"
// @Success 200 {object} User
// @Failure 404 {object} map[string]string
// @Router /users/{id} [get]
func getUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var u User
	err := db.QueryRow("SELECT id, email, name, age, created_at, updated_at FROM users WHERE id = $1", id).
		Scan(&u.ID, &u.Email, &u.Name, &u.Age, &u.CreatedAt, &u.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

// @Summary Create user
// @Description Создать нового пользователя
// @Tags users
// @Accept json
// @Produce json
// @Param user body User true "User data"
// @Success 201 {object} User
// @Failure 400 {object} map[string]string
// @Router /users [post]
func createUser(w http.ResponseWriter, r *http.Request) {
	var u User
	if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"INSERT INTO users (email, name, age) VALUES ($1, $2, $3) RETURNING id, created_at, updated_at",
		u.Email, u.Name, u.Age,
	).Scan(&u.ID, &u.CreatedAt, &u.UpdatedAt)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(u)
}

// @Summary Update user
// @Description Обновить данные пользователя
// @Tags users
// @Accept json
// @Produce json
// @Param id path int true "User ID"
// @Param user body User true "User data"
// @Success 200 {object} User
// @Failure 404 {object} map[string]string
// @Router /users/{id} [put]
func updateUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var u User
	if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"UPDATE users SET email=$1, name=$2, age=$3, updated_at=NOW() WHERE id=$4 RETURNING id, email, name, age, created_at, updated_at",
		u.Email, u.Name, u.Age, id,
	).Scan(&u.ID, &u.Email, &u.Name, &u.Age, &u.CreatedAt, &u.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

// @Summary Delete user
// @Description Удалить пользователя
// @Tags users
// @Param id path int true "User ID"
// @Success 204
// @Failure 404 {object} map[string]string
// @Router /users/{id} [delete]
func deleteUser(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	result, err := db.Exec("DELETE FROM users WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
EOFGO

# ============ ORDERS SERVICE ============
echo "📝 Обновляю orders-service..."
cat > orders-service/cmd/main.go << 'EOFGO'
package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	httpSwagger "github.com/swaggo/http-swagger"
	_ "orders-service/docs"
)

var db *sql.DB
var replicaID string

type Order struct {
	ID          int     `json:"id"`
	UserID      int     `json:"user_id" validate:"required"`
	TotalAmount float64 `json:"total_amount" validate:"required,gt=0"`
	Status      string  `json:"status" validate:"required,oneof=pending confirmed shipped delivered cancelled"`
	CreatedAt   string  `json:"createdAt"`
	UpdatedAt   string  `json:"updatedAt"`
}

type SystemInfo struct {
	ReplicaID string `json:"replica_id"`
	Timestamp string `json:"timestamp"`
}

// @title Orders Service API
// @version 1.0
// @description Микросервис управления заказами с балансировкой нагрузки
// @host localhost:8002
// @BasePath /
func main() {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	replicaID = os.Getenv("REPLICA_ID")
	if replicaID == "" {
		replicaID = "default"
	}

	var err error
	db, err = sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatalf("DB connection error: %v", err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatalf("DB ping error: %v", err)
	}
	log.Printf("✅ Connected to PostgreSQL (orders-service - %s)", replicaID)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8002"
	}

	router := mux.NewRouter()
	router.HandleFunc("/health", healthCheck).Methods("GET")
	router.HandleFunc("/system-id", getSystemID).Methods("GET")
	router.HandleFunc("/orders", getOrders).Methods("GET")
	router.HandleFunc("/orders/{id}", getOrder).Methods("GET")
	router.HandleFunc("/orders", createOrder).Methods("POST")
	router.HandleFunc("/orders/{id}", updateOrder).Methods("PUT")
	router.HandleFunc("/orders/{id}", deleteOrder).Methods("DELETE")
	
	router.PathPrefix("/swagger/").Handler(httpSwagger.WrapHandler)

	log.Printf("🚀 Orders Service (%s) started on port %s", replicaID, port)
	log.Printf("📚 Swagger UI: http://localhost:%s/swagger/index.html", port)
	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

// @Summary Health check
// @Description Проверка состояния сервиса
// @Tags health
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "replica_id": replicaID})
}

// @Summary Get system ID
// @Description Получить ID реплики для проверки балансировки
// @Tags system
// @Produce json
// @Success 200 {object} SystemInfo
// @Router /system-id [get]
func getSystemID(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(SystemInfo{
		ReplicaID: replicaID,
		Timestamp: "NOW()",
	})
}

// @Summary Get all orders
// @Description Получить список всех заказов
// @Tags orders
// @Produce json
// @Success 200 {array} Order
// @Router /orders [get]
func getOrders(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, user_id, total_amount, status, created_at, updated_at FROM orders ORDER BY id LIMIT 100")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var orders []Order
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.UserID, &o.TotalAmount, &o.Status, &o.CreatedAt, &o.UpdatedAt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		orders = append(orders, o)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orders)
}

// @Summary Get order by ID
// @Description Получить заказ по ID
// @Tags orders
// @Produce json
// @Param id path int true "Order ID"
// @Success 200 {object} Order
// @Failure 404 {object} map[string]string
// @Router /orders/{id} [get]
func getOrder(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var o Order
	err := db.QueryRow("SELECT id, user_id, total_amount, status, created_at, updated_at FROM orders WHERE id = $1", id).
		Scan(&o.ID, &o.UserID, &o.TotalAmount, &o.Status, &o.CreatedAt, &o.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Order not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(o)
}

// @Summary Create order
// @Description Создать новый заказ
// @Tags orders
// @Accept json
// @Produce json
// @Param order body Order true "Order data"
// @Success 201 {object} Order
// @Failure 400 {object} map[string]string
// @Router /orders [post]
func createOrder(w http.ResponseWriter, r *http.Request) {
	var o Order
	if err := json.NewDecoder(r.Body).Decode(&o); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"INSERT INTO orders (user_id, total_amount, status) VALUES ($1, $2, $3) RETURNING id, created_at, updated_at",
		o.UserID, o.TotalAmount, o.Status,
	).Scan(&o.ID, &o.CreatedAt, &o.UpdatedAt)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(o)
}

// @Summary Update order
// @Description Обновить данные заказа
// @Tags orders
// @Accept json
// @Produce json
// @Param id path int true "Order ID"
// @Param order body Order true "Order data"
// @Success 200 {object} Order
// @Failure 404 {object} map[string]string
// @Router /orders/{id} [put]
func updateOrder(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var o Order
	if err := json.NewDecoder(r.Body).Decode(&o); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"UPDATE orders SET user_id=$1, total_amount=$2, status=$3, updated_at=NOW() WHERE id=$4 RETURNING id, user_id, total_amount, status, created_at, updated_at",
		o.UserID, o.TotalAmount, o.Status, id,
	).Scan(&o.ID, &o.UserID, &o.TotalAmount, &o.Status, &o.CreatedAt, &o.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Order not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(o)
}

// @Summary Delete order
// @Description Удалить заказ
// @Tags orders
// @Param id path int true "Order ID"
// @Success 204
// @Failure 404 {object} map[string]string
// @Router /orders/{id} [delete]
func deleteOrder(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	result, err := db.Exec("DELETE FROM orders WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		http.Error(w, "Order not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
EOFGO

# ============ PAYMENTS SERVICE ============
echo "📝 Обновляю payments-service..."
cat > payments-service/cmd/main.go << 'EOFGO'
package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	httpSwagger "github.com/swaggo/http-swagger"
	_ "payments-service/docs"
)

var db *sql.DB

type Payment struct {
	ID            int     `json:"id"`
	OrderID       int     `json:"order_id" validate:"required"`
	Amount        float64 `json:"amount" validate:"required,gt=0"`
	Status        string  `json:"status" validate:"required,oneof=pending completed failed refunded"`
	PaymentMethod string  `json:"payment_method" validate:"required,oneof=card cash paypal"`
	CreatedAt     string  `json:"createdAt"`
	UpdatedAt     string  `json:"updatedAt"`
}

// @title Payments Service API
// @version 1.0
// @description Микросервис управления платежами
// @host localhost:8004
// @BasePath /
func main() {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	var err error
	db, err = sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatalf("DB connection error: %v", err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatalf("DB ping error: %v", err)
	}
	log.Printf("✅ Connected to PostgreSQL (payments-service)")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8003"
	}

	router := mux.NewRouter()
	router.HandleFunc("/health", healthCheck).Methods("GET")
	router.HandleFunc("/payments", getPayments).Methods("GET")
	router.HandleFunc("/payments/{id}", getPayment).Methods("GET")
	router.HandleFunc("/payments", createPayment).Methods("POST")
	router.HandleFunc("/payments/{id}", updatePayment).Methods("PUT")
	router.HandleFunc("/payments/{id}", deletePayment).Methods("DELETE")
	
	router.PathPrefix("/swagger/").Handler(httpSwagger.WrapHandler)

	log.Printf("🚀 Payments Service started on port %s", port)
	log.Printf("📚 Swagger UI: http://localhost:%s/swagger/index.html", port)
	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

// @Summary Health check
// @Description Проверка состояния сервиса
// @Tags health
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

// @Summary Get all payments
// @Description Получить список всех платежей
// @Tags payments
// @Produce json
// @Success 200 {array} Payment
// @Router /payments [get]
func getPayments(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, order_id, amount, status, payment_method, created_at, updated_at FROM payments ORDER BY id LIMIT 100")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var payments []Payment
	for rows.Next() {
		var p Payment
		if err := rows.Scan(&p.ID, &p.OrderID, &p.Amount, &p.Status, &p.PaymentMethod, &p.CreatedAt, &p.UpdatedAt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		payments = append(payments, p)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(payments)
}

// @Summary Get payment by ID
// @Description Получить платеж по ID
// @Tags payments
// @Produce json
// @Param id path int true "Payment ID"
// @Success 200 {object} Payment
// @Failure 404 {object} map[string]string
// @Router /payments/{id} [get]
func getPayment(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var p Payment
	err := db.QueryRow("SELECT id, order_id, amount, status, payment_method, created_at, updated_at FROM payments WHERE id = $1", id).
		Scan(&p.ID, &p.OrderID, &p.Amount, &p.Status, &p.PaymentMethod, &p.CreatedAt, &p.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Payment not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(p)
}

// @Summary Create payment
// @Description Создать новый платеж
// @Tags payments
// @Accept json
// @Produce json
// @Param payment body Payment true "Payment data"
// @Success 201 {object} Payment
// @Failure 400 {object} map[string]string
// @Router /payments [post]
func createPayment(w http.ResponseWriter, r *http.Request) {
	var p Payment
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"INSERT INTO payments (order_id, amount, status, payment_method) VALUES ($1, $2, $3, $4) RETURNING id, created_at, updated_at",
		p.OrderID, p.Amount, p.Status, p.PaymentMethod,
	).Scan(&p.ID, &p.CreatedAt, &p.UpdatedAt)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(p)
}

// @Summary Update payment
// @Description Обновить данные платежа
// @Tags payments
// @Accept json
// @Produce json
// @Param id path int true "Payment ID"
// @Param payment body Payment true "Payment data"
// @Success 200 {object} Payment
// @Failure 404 {object} map[string]string
// @Router /payments/{id} [put]
func updatePayment(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var p Payment
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"UPDATE payments SET order_id=$1, amount=$2, status=$3, payment_method=$4, updated_at=NOW() WHERE id=$5 RETURNING id, order_id, amount, status, payment_method, created_at, updated_at",
		p.OrderID, p.Amount, p.Status, p.PaymentMethod, id,
	).Scan(&p.ID, &p.OrderID, &p.Amount, &p.Status, &p.PaymentMethod, &p.CreatedAt, &p.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Payment not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(p)
}

// @Summary Delete payment
// @Description Удалить платеж
// @Tags payments
// @Param id path int true "Payment ID"
// @Success 204
// @Failure 404 {object} map[string]string
// @Router /payments/{id} [delete]
func deletePayment(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	result, err := db.Exec("DELETE FROM payments WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		http.Error(w, "Payment not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
EOFGO

# ============ DELIVERY SERVICE ============
echo "📝 Обновляю delivery-service..."
cat > delivery-service/cmd/main.go << 'EOFGO'
package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	httpSwagger "github.com/swaggo/http-swagger"
	_ "delivery-service/docs"
)

var db *sql.DB

type Delivery struct {
	ID         int    `json:"id"`
	OrderID    int    `json:"order_id" validate:"required"`
	Address    string `json:"address" validate:"required,min=10,max=500"`
	Status     string `json:"status" validate:"required,oneof=pending in_transit delivered failed"`
	CourierID  *int   `json:"courier_id"`
	CreatedAt  string `json:"createdAt"`
	UpdatedAt  string `json:"updatedAt"`
}

// @title Delivery Service API
// @version 1.0
// @description Микросервис управления доставкой
// @host localhost:8005
// @BasePath /
func main() {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL not set")
	}

	var err error
	db, err = sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatalf("DB connection error: %v", err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatalf("DB ping error: %v", err)
	}
	log.Printf("✅ Connected to PostgreSQL (delivery-service)")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8004"
	}

	router := mux.NewRouter()
	router.HandleFunc("/health", healthCheck).Methods("GET")
	router.HandleFunc("/deliveries", getDeliveries).Methods("GET")
	router.HandleFunc("/deliveries/{id}", getDelivery).Methods("GET")
	router.HandleFunc("/deliveries", createDelivery).Methods("POST")
	router.HandleFunc("/deliveries/{id}", updateDelivery).Methods("PUT")
	router.HandleFunc("/deliveries/{id}", deleteDelivery).Methods("DELETE")
	
	router.PathPrefix("/swagger/").Handler(httpSwagger.WrapHandler)

	log.Printf("🚀 Delivery Service started on port %s", port)
	log.Printf("📚 Swagger UI: http://localhost:%s/swagger/index.html", port)
	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

// @Summary Health check
// @Description Проверка состояния сервиса
// @Tags health
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

// @Summary Get all deliveries
// @Description Получить список всех доставок
// @Tags deliveries
// @Produce json
// @Success 200 {array} Delivery
// @Router /deliveries [get]
func getDeliveries(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, order_id, address, status, courier_id, created_at, updated_at FROM deliveries ORDER BY id LIMIT 100")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var deliveries []Delivery
	for rows.Next() {
		var d Delivery
		if err := rows.Scan(&d.ID, &d.OrderID, &d.Address, &d.Status, &d.CourierID, &d.CreatedAt, &d.UpdatedAt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		deliveries = append(deliveries, d)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(deliveries)
}

// @Summary Get delivery by ID
// @Description Получить доставку по ID
// @Tags deliveries
// @Produce json
// @Param id path int true "Delivery ID"
// @Success 200 {object} Delivery
// @Failure 404 {object} map[string]string
// @Router /deliveries/{id} [get]
func getDelivery(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var d Delivery
	err := db.QueryRow("SELECT id, order_id, address, status, courier_id, created_at, updated_at FROM deliveries WHERE id = $1", id).
		Scan(&d.ID, &d.OrderID, &d.Address, &d.Status, &d.CourierID, &d.CreatedAt, &d.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Delivery not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(d)
}

// @Summary Create delivery
// @Description Создать новую доставку
// @Tags deliveries
// @Accept json
// @Produce json
// @Param delivery body Delivery true "Delivery data"
// @Success 201 {object} Delivery
// @Failure 400 {object} map[string]string
// @Router /deliveries [post]
func createDelivery(w http.ResponseWriter, r *http.Request) {
	var d Delivery
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"INSERT INTO deliveries (order_id, address, status, courier_id) VALUES ($1, $2, $3, $4) RETURNING id, created_at, updated_at",
		d.OrderID, d.Address, d.Status, d.CourierID,
	).Scan(&d.ID, &d.CreatedAt, &d.UpdatedAt)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(d)
}

// @Summary Update delivery
// @Description Обновить данные доставки
// @Tags deliveries
// @Accept json
// @Produce json
// @Param id path int true "Delivery ID"
// @Param delivery body Delivery true "Delivery data"
// @Success 200 {object} Delivery
// @Failure 404 {object} map[string]string
// @Router /deliveries/{id} [put]
func updateDelivery(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	var d Delivery
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err := db.QueryRow(
		"UPDATE deliveries SET order_id=$1, address=$2, status=$3, courier_id=$4, updated_at=NOW() WHERE id=$5 RETURNING id, order_id, address, status, courier_id, created_at, updated_at",
		d.OrderID, d.Address, d.Status, d.CourierID, id,
	).Scan(&d.ID, &d.OrderID, &d.Address, &d.Status, &d.CourierID, &d.CreatedAt, &d.UpdatedAt)

	if err == sql.ErrNoRows {
		http.Error(w, "Delivery not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(d)
}

// @Summary Delete delivery
// @Description Удалить доставку
// @Tags deliveries
// @Param id path int true "Delivery ID"
// @Success 204
// @Failure 404 {object} map[string]string
// @Router /deliveries/{id} [delete]
func deleteDelivery(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, _ := strconv.Atoi(vars["id"])

	result, err := db.Exec("DELETE FROM deliveries WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		http.Error(w, "Delivery not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
EOFGO

echo ""
echo "✅ Все сервисы обновлены!"
echo ""
echo "Теперь запусти второй скрипт:"
echo "  chmod +x generate-swagger.sh"
echo "  ./generate-swagger.sh"
