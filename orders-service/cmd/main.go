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
