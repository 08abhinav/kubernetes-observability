package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func homeHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "Welcome to the Observability application")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "Healthy")
}

func slowHandler(w http.ResponseWriter, r *http.Request) {
	time.Sleep(2 * time.Second)

	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "Slow request completed")
}

func errorHandler(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "Simulated internal server error", http.StatusInternalServerError)
}

func main() {
	metrics, registry, err := newAppMetrics()
	if err != nil {
		log.Fatalf("failed to initialize metrics: %v", err)
	}

	app := http.NewServeMux()

	app.Handle("GET /metrics", promhttp.HandlerFor(
		registry,
		promhttp.HandlerOpts{},
	))

	app.HandleFunc("GET /{$}", homeHandler)
	app.HandleFunc("GET /health", healthHandler)
	app.HandleFunc("GET /slow", slowHandler)
	app.HandleFunc("GET /error", errorHandler)

	handler := metrics.middleware(app)

	server := &http.Server{
		Addr:         ":8080",
		Handler:      handler,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Println("Application listening on :8080")

	if err := server.ListenAndServe(); err != nil &&
		err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
