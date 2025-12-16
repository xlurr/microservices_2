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
