//go:build windows

package main

import (
	"os"
	"os/exec"
	"strings"
	"syscall"
)

func prepareCmd(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}

	// Inject Apple iTunes DLL directories into PATH
	env := os.Environ()
	applePaths := []string{
		`C:\Program Files\Common Files\Apple\Apple Application Support`,
		`C:\Program Files (x86)\Common Files\Apple\Apple Application Support`,
		`C:\Program Files\iTunes`,
		`C:\Program Files (x86)\iTunes`,
		`C:\Program Files\Common Files\Apple\Mobile Device Support`,
		`C:\Program Files (x86)\Common Files\Apple\Mobile Device Support`,
	}
	currentPath := os.Getenv("PATH")
	newPath := strings.Join(applePaths, ";") + ";" + currentPath

	hasPath := false
	for i, e := range env {
		if strings.HasPrefix(strings.ToUpper(e), "PATH=") {
			env[i] = "PATH=" + newPath
			hasPath = true
			break
		}
	}
	if !hasPath {
		env = append(env, "PATH="+newPath)
	}
	cmd.Env = env
}
