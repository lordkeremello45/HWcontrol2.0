package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type UpdateServiceStatus struct {
	CurrentVersion string `json:"currentVersion"`
	LatestVersion string `json:"latestVersion,omitempty"`
	UpdateAvailable bool `json:"updateAvailable"`
	Checked bool `json:"checked"`
	LocalOnly bool `json:"localOnly"`
	Source string `json:"source"`
	Error string `json:"error,omitempty"`
}

func checkForUpdates(ctx context.Context) UpdateServiceStatus {
	s:=UpdateServiceStatus{CurrentVersion:bridgeVersion,Source:"github-releases"}
	req,err:=http.NewRequestWithContext(ctx,http.MethodGet,"https://api.github.com/repos/lordkeremello45/HWcontrol2.0/releases/latest",nil)
	if err!=nil { s.Error="create update request failed"; return s }
	req.Header.Set("Accept","application/vnd.github+json")
	req.Header.Set("User-Agent","HWcontrol2.0-Update-Service/"+bridgeVersion)
	resp,err:=(&http.Client{Timeout:5*time.Second}).Do(req)
	if err!=nil { s.Error="update metadata unavailable"; return s }
	defer resp.Body.Close()
	if resp.StatusCode!=http.StatusOK { s.Error=fmt.Sprintf("update metadata returned HTTP %d",resp.StatusCode); return s }
	var p struct{TagName string `json:"tag_name"`}
	if err:=json.NewDecoder(resp.Body).Decode(&p); err!=nil { s.Error="invalid update metadata"; return s }
	s.Checked=true
	s.LatestVersion=strings.TrimSpace(strings.TrimPrefix(p.TagName,"v"))
	s.UpdateAvailable=s.LatestVersion!="" && s.LatestVersion!=bridgeVersion
	return s
}
