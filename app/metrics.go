package main

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type appMetrics struct {
	requestsTotal    *prometheus.CounterVec
	requestDuration  *prometheus.HistogramVec
	errorsTotal      *prometheus.CounterVec
	requestsInFlight prometheus.Gauge
}

func newAppMetrics() (*appMetrics, *prometheus.Registry, error) {
	m := &appMetrics{
		requestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests",
			},
			[]string{"method", "status"},
		),

		requestDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "http_request_duration_seconds",
				Help:    "Http request duration in seconds",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"method"},
		),

		errorsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_errors_total",
				Help: "Total number of HTTP 5xx responses.",
			},
			[]string{"method", "status"},
		),

		requestsInFlight: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Name: "http_requests_in_flight",
				Help: "Number of HTTP requests currently being processed.",
			},
		),
	}

	registry := prometheus.NewRegistry()

	collectors := []prometheus.Collector{
		m.requestsTotal,
		m.requestDuration,
		m.errorsTotal,
		m.requestsInFlight,
		prometheus.NewGoCollector(),
		prometheus.NewProcessCollector(
			prometheus.ProcessCollectorOpts{},
		),
	}

	for _, collector := range collectors {
		if err := registry.Register(collector); err != nil {
			return nil, nil, err
		}
	}

	return m, registry, nil
}

func (m *appMetrics) middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Do not include Prometheus scraping in application metrics.
		if r.URL.Path == "/metrics" {
			next.ServeHTTP(w, r)
			return
		}

		start := time.Now()

		m.requestsInFlight.Inc()
		defer m.requestsInFlight.Dec()

		recorder := &statusRecorder{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		next.ServeHTTP(recorder, r)

		duration := time.Since(start).Seconds()
		method := r.Method
		status := strconv.Itoa(recorder.statusCode)

		m.requestsTotal.WithLabelValues(method, status).Inc()
		m.requestDuration.WithLabelValues(method).Observe(duration)

		if recorder.statusCode >= 500 {
			m.errorsTotal.WithLabelValues(method, status).Inc()
		}
	})
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode  int
	wroteHeader bool
}

func (r *statusRecorder) WriteHeader(code int) {
	if r.wroteHeader {
		return
	}

	r.statusCode = code
	r.wroteHeader = true
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Write(data []byte) (int, error) {
	if !r.wroteHeader {
		r.WriteHeader(http.StatusOK)
	}

	return r.ResponseWriter.Write(data)
}
