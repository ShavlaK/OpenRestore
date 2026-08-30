package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
)

const KeychainPassphrase = "openrestore_passphrase_v1"

type DeviceInfo struct {
	UDID           string `json:"udid"`
	DeviceName     string `json:"deviceName"`
	ProductType    string `json:"productType"`
	ProductVersion string `json:"productVersion"`
	ConnectionType string `json:"connectionType"` // "USB" or "WiFi"
	IsOnline       bool   `json:"isOnline"`
}

type PurchaseItem struct {
	ID        int64  `json:"id"`
	Name      string `json:"name"`
	BundleID  string `json:"bundleId"`
	IconURL   string `json:"iconUrl"`
	Version   string `json:"version"`
	ByteSize  int64  `json:"byteSize"`
	IsLocal   bool   `json:"isLocal"`
}

type LibraryIPA struct {
	FileName  string `json:"fileName"`
	FilePath  string `json:"filePath"`
	SizeMB    string `json:"sizeMb"`
	ModTime   string `json:"modTime"`
	BundleID  string `json:"bundleId"`
	AppName   string `json:"appName"`
}

type ProgressEvent struct {
	Type     string  `json:"type"` // "progress", "log", "complete", "error"
	Stage    string  `json:"stage"`
	Percent  float64 `json:"percent"`
	Log      string  `json:"log"`
}

type AppEngine struct {
	mu           sync.RWMutex
	binDir       string
	downloadsDir string
	clients      map[chan ProgressEvent]bool
	clientsMu    sync.Mutex
	currentDevice *DeviceInfo
	appleID      string
	appleName    string
	isLoggedIn   bool
}

func NewAppEngine() *AppEngine {
	exePath, _ := os.Executable()
	baseDir := filepath.Dir(exePath)
	
	binDir := filepath.Join(baseDir, "bin")
	if _, err := os.Stat(binDir); os.IsNotExist(err) {
		binDir = "bin"
	}

	userProfile := os.Getenv("USERPROFILE")
	if userProfile == "" {
		userProfile, _ = os.UserHomeDir()
	}
	downloadsDir := filepath.Join(userProfile, "Downloads", "OpenRestore")
	os.MkdirAll(downloadsDir, 0755)

	return &AppEngine{
		binDir:       binDir,
		downloadsDir: downloadsDir,
		clients:      make(map[chan ProgressEvent]bool),
	}
}

func (e *AppEngine) GetBinary(name string) string {
	if runtime.GOOS == "windows" && !strings.HasSuffix(name, ".exe") {
		name += ".exe"
	}
	return filepath.Join(e.binDir, name)
}

func (e *AppEngine) Broadcast(evt ProgressEvent) {
	e.clientsMu.Lock()
	defer e.clientsMu.Unlock()
	for ch := range e.clients {
		select {
		case ch <- evt:
		default:
		}
	}
}

func (e *AppEngine) Subscribe() chan ProgressEvent {
	e.clientsMu.Lock()
	defer e.clientsMu.Unlock()
	ch := make(chan ProgressEvent, 100)
	e.clients[ch] = true
	return ch
}

func (e *AppEngine) Unsubscribe(ch chan ProgressEvent) {
	e.clientsMu.Lock()
	defer e.clientsMu.Unlock()
	delete(e.clients, ch)
	close(ch)
}

func (e *AppEngine) Log(msg string) {
	fmt.Println(msg)
	e.Broadcast(ProgressEvent{
		Type: "log",
		Log:  msg,
	})
}

// Check devices using go-ios (ios.exe list) with NO popup console windows
func (e *AppEngine) GetDevices() ([]DeviceInfo, error) {
	iosBin := e.GetBinary("ios")
	cmd := exec.Command(iosBin, "list")
	prepareCmd(cmd)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("ошибка вызова ios.exe: %v", err)
	}

	var devices []DeviceInfo
	lines := strings.Split(string(out), "\n")
	
	// Check if JSON output
	var jsonDevices []struct {
		DeviceList []struct {
			Udid           string `json:"udid"`
			DeviceName     string `json:"device_name"`
			ProductType    string `json:"product_type"`
			ProductVersion string `json:"product_version"`
			ConnectionType string `json:"connection_type"`
		} `json:"device_list"`
	}
	if err := json.Unmarshal(out, &jsonDevices); err == nil && len(jsonDevices) > 0 {
		for _, dl := range jsonDevices {
			for _, d := range dl.DeviceList {
				conn := "USB"
				if strings.Contains(strings.ToLower(d.ConnectionType), "network") || strings.Contains(strings.ToLower(d.ConnectionType), "wifi") {
					conn = "WiFi"
				}
				devices = append(devices, DeviceInfo{
					UDID:           d.Udid,
					DeviceName:     d.DeviceName,
					ProductType:    d.ProductType,
					ProductVersion: d.ProductVersion,
					ConnectionType: conn,
					IsOnline:       true,
				})
			}
		}
		if len(devices) > 0 {
			return devices, nil
		}
	}

	// Line-based fallback
	for _, l := range lines {
		l = strings.TrimSpace(l)
		if l == "" || strings.HasPrefix(l, "UDID") || strings.HasPrefix(l, "--") {
			continue
		}
		parts := strings.Fields(l)
		if len(parts) >= 1 {
			udid := parts[0]
			conn := "USB"
			if strings.Contains(strings.ToLower(l), "wifi") || strings.Contains(strings.ToLower(l), "network") {
				conn = "WiFi"
			}
			devices = append(devices, DeviceInfo{
				UDID:           udid,
				DeviceName:     "iPhone (" + udid[:min(8, len(udid))] + "…)",
				ProductType:    "iPhone",
				ProductVersion: "iOS",
				ConnectionType: conn,
				IsOnline:       true,
			})
		}
	}

	return devices, nil
}

// Check Apple ID Status via ipatool
func (e *AppEngine) CheckAuthStatus() (bool, string, string) {
	ipatool := e.GetBinary("ipatool")
	cmd := exec.Command(ipatool, "auth", "status", "--format", "json", "--non-interactive", "--keychain-passphrase", KeychainPassphrase)
	prepareCmd(cmd)
	out, err := cmd.CombinedOutput()
	if err != nil {
		e.mu.Lock()
		e.isLoggedIn = false
		e.appleID = ""
		e.appleName = ""
		e.mu.Unlock()
		return false, "", ""
	}

	var status struct {
		Name  string `json:"name"`
		Email string `json:"email"`
	}
	if err := json.Unmarshal(out, &status); err == nil && status.Email != "" {
		e.mu.Lock()
		e.isLoggedIn = true
		e.appleID = status.Email
		e.appleName = status.Name
		e.mu.Unlock()
		return true, status.Email, status.Name
	}

	return false, "", ""
}

// Login Apple ID with 2FA & Non-interactive mode
func (e *AppEngine) Login(email, password, authCode string) (bool, string) {
	ipatool := e.GetBinary("ipatool")
	args := []string{
		"auth", "login",
		"--email", email,
		"--password", password,
		"--keychain-passphrase", KeychainPassphrase,
		"--non-interactive",
		"--format", "json",
	}
	if authCode != "" {
		args = append(args, "--auth-code", authCode)
	}

	e.Log(fmt.Sprintf("🔑 Авторизация Apple ID (%s)...", email))
	cmd := exec.Command(ipatool, args...)
	prepareCmd(cmd)
	out, err := cmd.CombinedOutput()
	outStr := strings.TrimSpace(string(out))
	e.Log(fmt.Sprintf("Результат ipatool: %s", outStr))

	if err != nil {
		lower := strings.ToLower(outStr)
		if strings.Contains(lower, "2fa") || strings.Contains(lower, "code") || strings.Contains(lower, "two-factor") || strings.Contains(lower, "verification") || strings.Contains(lower, "required") || strings.Contains(lower, "security") {
			return false, "NEED_2FA"
		}
		
		// Parse JSON error if present
		errMsg := outStr
		lines := strings.Split(outStr, "\n")
		for _, line := range lines {
			if strings.Contains(line, "\"error\"") {
				var j map[string]interface{}
				if err := json.Unmarshal([]byte(line), &j); err == nil {
					if e, ok := j["error"].(string); ok {
						errMsg = e
						break
					}
				}
			}
		}

		if errMsg == "" {
			errMsg = err.Error()
		}
		if strings.Contains(lower, "anisette") || strings.Contains(lower, "apple application support") {
			errMsg = "Для входа требуется установить iTunes с официального сайта Apple (не из Microsoft Store)."
		}
		
		return false, errMsg
	}

	e.CheckAuthStatus()
	return true, "OK"
}

// Get Purchases with Local Caching & Pagination
func (e *AppEngine) GetPurchases(forceRefresh bool) ([]PurchaseItem, error) {
	cachePath := filepath.Join(e.downloadsDir, "purchases_cache.json")
	
	if !forceRefresh {
		if data, err := os.ReadFile(cachePath); err == nil {
			var cached []PurchaseItem
			if err := json.Unmarshal(data, &cached); err == nil && len(cached) > 0 {
				e.Log(fmt.Sprintf("⚡ Загружено %d покупок из локального кэша", len(cached)))
				return cached, nil
			}
		}
	}

	ipatool := e.GetBinary("ipatool")
	var allPurchases []PurchaseItem
	seenIDs := make(map[int64]bool)

	for page := 1; page <= 25; page++ {
		e.Log(fmt.Sprintf("⏳ Загрузка страницы покупок #%d...", page))
		e.Broadcast(ProgressEvent{
			Type:    "progress",
			Stage:   fmt.Sprintf("Загрузка покупок (страница %d)...", page),
			Percent: float64(page) * 4.0,
		})

		cmd := exec.Command(ipatool, "list-purchases", "-p", strconv.Itoa(page), "--non-interactive", "--format", "json", "--keychain-passphrase", KeychainPassphrase)
		prepareCmd(cmd)
		out, err := cmd.CombinedOutput()
		if err != nil {
			break
		}

		var pageItems []PurchaseItem
		if err := json.Unmarshal(out, &pageItems); err != nil || len(pageItems) == 0 {
			break
		}

		newAdded := 0
		for _, item := range pageItems {
			if !seenIDs[item.ID] {
				seenIDs[item.ID] = true
				allPurchases = append(allPurchases, item)
				newAdded++
			}
		}

		if newAdded == 0 {
			break
		}
	}

	if len(allPurchases) > 0 {
		if cacheData, err := json.MarshalIndent(allPurchases, "", "  "); err == nil {
			os.WriteFile(cachePath, cacheData, 0644)
		}
	}

	e.Broadcast(ProgressEvent{
		Type:    "progress",
		Stage:   fmt.Sprintf("Готово! Загружено %d покупок", len(allPurchases)),
		Percent: 100.0,
	})

	return allPurchases, nil
}

// Download IPA with Live Progress Stream
func (e *AppEngine) DownloadIPA(adamID int64, bundleID string, appName string) (string, error) {
	ipatool := e.GetBinary("ipatool")
	outputPath := filepath.Join(e.downloadsDir, fmt.Sprintf("%s_%d.ipa", sanitizeFilename(appName), adamID))
	
	args := []string{
		"download",
		"-i", strconv.FormatInt(adamID, 10),
		"--purchase",
		"-o", outputPath,
		"--non-interactive",
		"--format", "json",
		"--keychain-passphrase", KeychainPassphrase,
	}

	e.Log(fmt.Sprintf("⬇️ Загрузка приложения «%s» (ID: %d)...", appName, adamID))
	e.Broadcast(ProgressEvent{
		Type:    "progress",
		Stage:   fmt.Sprintf("Загрузка «%s» с серверов Apple...", appName),
		Percent: 5.0,
	})

	cmd := exec.Command(ipatool, args...)
	prepareCmd(cmd)
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return "", err
	}
	cmd.Stderr = cmd.Stdout

	if err := cmd.Start(); err != nil {
		return "", err
	}

	rePercent := regexp.MustCompile(`(\d+)%`)
	reader := bufio.NewReader(stdoutPipe)
	for {
		line, err := reader.ReadString('\r')
		if len(line) > 0 {
			cleanLine := strings.TrimSpace(line)
			if match := rePercent.FindStringSubmatch(cleanLine); len(match) > 1 {
				if pct, err := strconv.ParseFloat(match[1], 64); err == nil {
					scaled := (pct / 100.0) * 70.0
					e.Broadcast(ProgressEvent{
						Type:    "progress",
						Stage:   fmt.Sprintf("Загрузка... %d%%", int(pct)),
						Percent: scaled,
						Log:     cleanLine,
					})
				}
			}
		}
		if err != nil {
			break
		}
	}

	if err := cmd.Wait(); err != nil {
		return "", fmt.Errorf("ошибка скачивания: %v", err)
	}

	// Verify file size
	if fi, err := os.Stat(outputPath); err != nil || fi.Size() < 500*1024 {
		os.Remove(outputPath)
		return "", fmt.Errorf("скачанный файл поврежден или отсутствует лицензия")
	}

	e.Broadcast(ProgressEvent{
		Type:    "progress",
		Stage:   "Загрузка завершена (100%)",
		Percent: 70.0,
	})
	e.Log(fmt.Sprintf("✅ Приложение сохранено: %s", outputPath))
	return outputPath, nil
}

// Install IPA onto connected iPhone with Live Progress Stream
func (e *AppEngine) InstallIPA(ipaPath string) error {
	iosBin := e.GetBinary("ios")
	e.Log(fmt.Sprintf("📲 Установка IPA на iPhone: %s...", filepath.Base(ipaPath)))
	
	e.Broadcast(ProgressEvent{
		Type:    "progress",
		Stage:   "Передача и распаковка на iPhone...",
		Percent: 75.0,
	})

	cmd := exec.Command(iosBin, "install", "--path", ipaPath)
	prepareCmd(cmd)
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	cmd.Stderr = cmd.Stdout

	if err := cmd.Start(); err != nil {
		return err
	}

	rePercent := regexp.MustCompile(`\[(\d+)%\]`)
	reader := bufio.NewReader(stdoutPipe)
	for {
		line, err := reader.ReadString('\n')
		if len(line) > 0 {
			cleanLine := strings.TrimSpace(line)
			e.Log("📱 " + cleanLine)
			if match := rePercent.FindStringSubmatch(cleanLine); len(match) > 1 {
				if pct, err := strconv.ParseFloat(match[1], 64); err == nil {
					scaled := 70.0 + (pct / 100.0) * 30.0
					e.Broadcast(ProgressEvent{
						Type:    "progress",
						Stage:   fmt.Sprintf("Установка на iPhone... %d%%", int(pct)),
						Percent: scaled,
						Log:     cleanLine,
					})
				}
			}
		}
		if err != nil {
			break
		}
	}

	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("ошибка установки: %v", err)
	}

	e.Broadcast(ProgressEvent{
		Type:    "complete",
		Stage:   "🎉 Приложение успешно установлено на iPhone!",
		Percent: 100.0,
	})
	e.Log("🎉 Установка успешно завершена!")
	return nil
}

// Get Local Library IPAs
func (e *AppEngine) GetLibrary() ([]LibraryIPA, error) {
	var list []LibraryIPA
	entries, err := os.ReadDir(e.downloadsDir)
	if err != nil {
		return nil, err
	}

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(strings.ToLower(entry.Name()), ".ipa") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		
		// Clean corrupted small files
		if info.Size() < 500*1024 {
			os.Remove(filepath.Join(e.downloadsDir, entry.Name()))
			continue
		}

		sizeMB := fmt.Sprintf("%.1f МБ", float64(info.Size())/(1024*1024))
		list = append(list, LibraryIPA{
			FileName: entry.Name(),
			FilePath: filepath.Join(e.downloadsDir, entry.Name()),
			SizeMB:   sizeMB,
			ModTime:  info.ModTime().Format("02.01.2006 15:04"),
			AppName:  strings.TrimSuffix(entry.Name(), ".ipa"),
		})
	}
	return list, nil
}

func sanitizeFilename(s string) string {
	invalid := []string{"/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "}
	res := s
	for _, c := range invalid {
		res = strings.ReplaceAll(res, c, "_")
	}
	return res
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
