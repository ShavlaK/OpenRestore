package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os/exec"
	"runtime"
)

type APIHandler struct {
	engine *AppEngine
}

func NewAPIHandler(engine *AppEngine) *APIHandler {
	return &APIHandler{engine: engine}
}

func (h *APIHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/status", h.handleStatus)
	mux.HandleFunc("/api/devices", h.handleDevices)
	mux.HandleFunc("/api/auth/status", h.handleAuthStatus)
	mux.HandleFunc("/api/auth/login", h.handleLogin)
	mux.HandleFunc("/api/purchases", h.handlePurchases)
	mux.HandleFunc("/api/download", h.handleDownload)
	mux.HandleFunc("/api/install", h.handleInstall)
	mux.HandleFunc("/api/library", h.handleLibrary)
	mux.HandleFunc("/api/open-folder", h.handleOpenFolder)
	mux.HandleFunc("/api/updates/check", h.handleCheckUpdates)
	mux.HandleFunc("/api/updates/install", h.handleInstallUpdate)
	mux.HandleFunc("/api/events", h.handleEvents)
}

func (h *APIHandler) handleStatus(w http.ResponseWriter, r *http.Request) {
	isLoggedIn, email, name := h.engine.CheckAuthStatus()
	devices, _ := h.engine.GetDevices()

	resp := map[string]interface{}{
		"isLoggedIn":   isLoggedIn,
		"appleEmail":   email,
		"appleName":    name,
		"downloadsDir": h.engine.downloadsDir,
		"deviceCount":  len(devices),
		"devices":      devices,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *APIHandler) handleDevices(w http.ResponseWriter, r *http.Request) {
	devices, err := h.engine.GetDevices()
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(devices)
}

func (h *APIHandler) handleAuthStatus(w http.ResponseWriter, r *http.Request) {
	isLoggedIn, email, name := h.engine.CheckAuthStatus()
	resp := map[string]interface{}{
		"isLoggedIn": isLoggedIn,
		"email":      email,
		"name":       name,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *APIHandler) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
		AuthCode string `json:"authCode"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	ok, msg := h.engine.Login(req.Email, req.Password, req.AuthCode)
	resp := map[string]interface{}{
		"success": ok,
		"message": msg,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *APIHandler) handlePurchases(w http.ResponseWriter, r *http.Request) {
	forceRefresh := r.URL.Query().Get("refresh") == "true"
	purchases, err := h.engine.GetPurchases(forceRefresh)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(purchases)
}

func (h *APIHandler) handleDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req struct {
		AdamID   int64  `json:"adamId"`
		BundleID string `json:"bundleId"`
		AppName  string `json:"appName"`
		Install  bool   `json:"install"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	go func() {
		ipaPath, err := h.engine.DownloadIPA(req.AdamID, req.BundleID, req.AppName)
		if err != nil {
			h.engine.Broadcast(ProgressEvent{
				Type:  "error",
				Stage: fmt.Sprintf("❌ Ошибка загрузки: %v", err),
			})
			return
		}

		if req.Install {
			if err := h.engine.InstallIPA(ipaPath); err != nil {
				h.engine.Broadcast(ProgressEvent{
					Type:  "error",
					Stage: fmt.Sprintf("❌ Ошибка установки: %v", err),
				})
			}
		}
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "started"})
}

func (h *APIHandler) handleInstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req struct {
		FilePath string `json:"filePath"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	go func() {
		if err := h.engine.InstallIPA(req.FilePath); err != nil {
			h.engine.Broadcast(ProgressEvent{
				Type:  "error",
				Stage: fmt.Sprintf("❌ Ошибка установки: %v", err),
			})
		}
	}()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "started"})
}

func (h *APIHandler) handleLibrary(w http.ResponseWriter, r *http.Request) {
	list, err := h.engine.GetLibrary()
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

func (h *APIHandler) handleOpenFolder(w http.ResponseWriter, r *http.Request) {
	dir := h.engine.downloadsDir
	if runtime.GOOS == "windows" {
		exec.Command("explorer.exe", dir).Start()
	} else if runtime.GOOS == "darwin" {
		exec.Command("open", dir).Start()
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "opened"})
}

func (h *APIHandler) handleEvents(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", 500)
		return
	}

	ch := h.engine.Subscribe()
	defer h.engine.Unsubscribe(ch)

	notify := r.Context().Done()

	for {
		select {
		case <-notify:
			return
		case evt, ok := <-ch:
			if !ok {
				return
			}
			data, _ := json.Marshal(evt)
			fmt.Fprintf(w, "data: %s\n\n", data)
			flusher.Flush()
		}
	}
}

func (h *APIHandler) handleCheckUpdates(w http.ResponseWriter, r *http.Request) {
	info, err := h.engine.CheckForUpdates()
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

func (h *APIHandler) handleInstallUpdate(w http.ResponseWriter, r *http.Request) {
	go func() {
		_ = h.engine.PerformSelfUpdate()
	}()
	resp := map[string]interface{}{
		"success": true,
		"message": "Обновление запущено",
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

