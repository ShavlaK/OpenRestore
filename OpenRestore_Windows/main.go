package main

import (
	"embed"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"
)

//go:embed web/*
var webFS embed.FS

func main() {
	engine := NewAppEngine()
	api := NewAPIHandler(engine)

	mux := http.NewServeMux()
	api.RegisterRoutes(mux)

	// Serve embedded web UI
	webContent, err := fs.Sub(webFS, "web")
	if err != nil {
		fmt.Printf("Error accessing embedded assets: %v\n", err)
		return
	}
	mux.Handle("/", http.FileServer(http.FS(webContent)))

	// Find available port on localhost
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Printf("Failed to bind port: %v\n", err)
		return
	}
	port := listener.Addr().(*net.TCPAddr).Port
	url := fmt.Sprintf("http://127.0.0.1:%d", port)

	fmt.Printf("⚡ OpenRestore Windows Server running at: %s\n", url)

	go func() {
		if err := http.Serve(listener, mux); err != nil {
			fmt.Printf("Server stopped: %v\n", err)
		}
	}()

	// Launch App Window
	time.Sleep(300 * time.Millisecond)
	openAppWindow(url)

	// Keep running
	select {}
}

func openAppWindow(url string) {
	if runtime.GOOS == "windows" {
		tempUserData := filepath.Join(os.Getenv("TEMP"), "openrestore_edge_profile")
		edgePaths := []string{
			`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`,
			`C:\Program Files\Microsoft\Edge\Application\msedge.exe`,
			filepath.Join(os.Getenv("LOCALAPPDATA"), `Microsoft\Edge\Application\msedge.exe`),
			`C:\Program Files\Google\Chrome\Application\chrome.exe`,
			`C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`,
			filepath.Join(os.Getenv("LOCALAPPDATA"), `Google\Chrome\Application\chrome.exe`),
		}

		for _, path := range edgePaths {
			if _, err := os.Stat(path); err == nil {
				cmd := exec.Command(path,
					fmt.Sprintf("--app=%s", url),
					"--window-size=1200,820",
					fmt.Sprintf("--user-data-dir=%s", tempUserData),
					"--no-first-run",
					"--no-default-browser-check",
					"--disable-extensions",
					"--disable-default-apps",
					"--disable-popup-blocking",
					"--disable-translate",
					"--disable-features=TranslateUI,OptimizationHints,MediaRouter,SidePanel",
					"--disable-component-update",
					"--disable-sync",
					"--disable-background-networking",
					"--app-auto-launched",
				)
				prepareCmd(cmd)
				if err := cmd.Start(); err == nil {
					return
				}
			}
		}

		// Fallback to default browser
		cmd := exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
		prepareCmd(cmd)
		cmd.Start()
	} else if runtime.GOOS == "darwin" {
		exec.Command("open", url).Start()
	} else {
		exec.Command("xdg-open", url).Start()
	}
}
