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
