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

	fmt.Printf("⚡ OpenStore Windows Server running at: %s\n", url)

	go func() {
		if err := http.Serve(listener, mux); err != nil {
			fmt.Printf("Server stopped: %v\n", err)
		}
	}()

	// Launch App Window
	time.Sleep(300 * time.Millisecond)
	cmd := openAppWindow(url)

	if cmd != nil {
		cmd.Wait() // Wait for the browser window to close
	} else {
		// Keep running if we couldn't launch an isolated browser window
		select {}
	}
	
	// Cleanup background processes before exiting
	fmt.Println("Cleaning up background processes...")
	if runtime.GOOS == "windows" {
		exec.Command("taskkill", "/F", "/IM", "os-store-helper.exe", "/T").Run()
		exec.Command("taskkill", "/F", "/IM", "os-agent.exe", "/T").Run()
		exec.Command("taskkill", "/F", "/IM", "ipatool.exe", "/T").Run()
		exec.Command("taskkill", "/F", "/IM", "ios.exe", "/T").Run()
	}
}

func openAppWindow(url string) *exec.Cmd {
	if runtime.GOOS == "windows" {
		tempUserData := filepath.Join(os.Getenv("TEMP"), "openstore_edge_profile")
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
				if err := cmd.Start(); err == nil {
					return cmd
				}
			}
		}

		// Fallback to default browser
		cmd := exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
		cmd.Start()
		return nil
	} else if runtime.GOOS == "darwin" {
		exec.Command("open", url).Start()
		return nil
	} else {
		exec.Command("xdg-open", url).Start()
		return nil
	}
}
