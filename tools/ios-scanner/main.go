package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/danielpaulus/go-ios/ios"
	"howett.net/plist"
)

type AppInfo map[string]any

type BrowseResponse struct {
	CurrentIndex  uint64
	CurrentAmount uint64
	Status        string
	CurrentList   []AppInfo
}

type DiscoveredApp struct {
	Name        string `json:"name"`
	DisplayName string `json:"displayName"`
	BundleID    string `json:"bundleId"`
	Version     string `json:"version"`
	AdamID      uint64 `json:"adamId,omitempty"`
	ArtworkURL  string `json:"artworkUrl,omitempty"`
}

func main() {
	udidFlag := flag.String("udid", "", "Target device UDID")
	flag.Parse()

	device, err := ios.GetDevice(*udidFlag)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting device: %v\n", err)
		// Output empty JSON array on error
		fmt.Println("[]")
		os.Exit(0)
	}

	deviceConn, err := ios.ConnectToService(device, "com.apple.mobile.installation_proxy")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connecting to service: %v\n", err)
		fmt.Println("[]")
		os.Exit(0)
	}
	defer deviceConn.Close()

	codec := ios.NewPlistCodec()

	clientOptions := map[string]any{
		"ApplicationType": "User",
		"ReturnAttributes": []string{
			"CFBundleIdentifier",
			"CFBundleDisplayName",
			"CFBundleName",
			"CFBundleShortVersionString",
			"CFBundleVersion",
			"iTunesMetadata",
			"ApplicationDSID",
			"Path",
			"Container",
			"softwareVersionExternalIdentifier",
		},
	}
	request := map[string]any{
		"Command":       "Browse",
		"ClientOptions": clientOptions,
	}

	reqBytes, err := codec.Encode(request)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Encode error: %v\n", err)
		fmt.Println("[]")
		os.Exit(0)
	}

	if err := deviceConn.Send(reqBytes); err != nil {
		fmt.Fprintf(os.Stderr, "Send error: %v\n", err)
		fmt.Println("[]")
		os.Exit(0)
	}

	reader := deviceConn.Reader()
	var allApps []AppInfo
	for {
		respBytes, err := codec.Decode(reader)
		if err != nil {
			break
		}

		var browseResp BrowseResponse
		decoder := plist.NewDecoder(bytes.NewReader(respBytes))
		if err := decoder.Decode(&browseResp); err != nil {
			break
		}

		allApps = append(allApps, browseResp.CurrentList...)
		if browseResp.Status == "Complete" {
			break
		}
	}

	var results []DiscoveredApp
	for _, app := range allApps {
		bundleID, _ := app["CFBundleIdentifier"].(string)
		if bundleID == "" {
			continue
		}

		dispName, _ := app["CFBundleDisplayName"].(string)
		if dispName == "" {
			dispName, _ = app["CFBundleName"].(string)
		}
		if dispName == "" {
			dispName = bundleID
		}

		ver, _ := app["CFBundleShortVersionString"].(string)
		if ver == "" {
			ver, _ = app["CFBundleVersion"].(string)
		}

		var adamID uint64 = 0

		if metaRaw, ok := app["iTunesMetadata"].([]byte); ok {
			var metaDict map[string]any
			dec := plist.NewDecoder(bytes.NewReader(metaRaw))
			if err := dec.Decode(&metaDict); err == nil {
				if iId, ok := metaDict["itemId"].(uint64); ok {
					adamID = iId
				} else if iId, ok := metaDict["itemId"].(int64); ok {
					adamID = uint64(iId)
				}
			}
		}

		results = append(results, DiscoveredApp{
			Name:        dispName,
			DisplayName: dispName,
			BundleID:    bundleID,
			Version:     ver,
			AdamID:      adamID,
		})
	}

	jsonBytes, err := json.Marshal(results)
	if err != nil {
		fmt.Println("[]")
		os.Exit(0)
	}

	fmt.Println(string(jsonBytes))
}
