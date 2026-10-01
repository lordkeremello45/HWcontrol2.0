package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const canaryName = "bridger.key"

func decoyDir() string {
	if v:=strings.TrimSpace(os.Getenv("HWCONTROL_DECOY_DIR")); v!="" { return v }
	switch runtime.GOOS {
	case "windows":
		root:=os.Getenv("ProgramData"); if root=="" { root="C:\ProgramData" }
		return filepath.Join(root,"HWControl","security")
	case "darwin":
		return filepath.Join("/Library","Application Support","HWControl","security")
	default:
		return "/var/lib/hwcontrol/security"
	}
}
func canaryPath() string { return filepath.Join(decoyDir(),canaryName) }
func panicPath() string {
	if v:=strings.TrimSpace(os.Getenv("HWCONTROL_PANIC_FILE")); v!="" { return v }
	return filepath.Join(decoyDir(),"panic-mode.json")
}
func digest(path string)(string,error){b,e:=os.ReadFile(path);if e!=nil{return "",e};h:=sha256.Sum256(b);return hex.EncodeToString(h[:]),nil}
func writePanic(reason string) error {
	if err:=os.MkdirAll(filepath.Dir(panicPath()),0700);err!=nil{return err}
	payload:=map[string]any{"panic":true,"reason":reason,"source":"security-guardian","timestamp":time.Now().UTC().Format(time.RFC3339Nano)}
	b,err:=json.Marshal(payload);if err!=nil{return err}
	tmp:=panicPath()+".tmp"
	if err=os.WriteFile(tmp,append(b,'\n'),0600);err!=nil{return err}
	return os.Rename(tmp,panicPath())
}
func ensureCanary() error {
	p:=canaryPath()
	if _,err:=os.Stat(p);err!=nil{return fmt.Errorf("canary unavailable: %w",err)}
	return nil
}
func main(){
	if err:=ensureCanary();err!=nil { fmt.Fprintln(os.Stderr,err); os.Exit(1) }
	baseline,err:=digest(canaryPath());if err!=nil{fmt.Fprintln(os.Stderr,err);os.Exit(1)}
	ticker:=time.NewTicker(2*time.Second);defer ticker.Stop()
	for range ticker.C {
		current,err:=digest(canaryPath())
		if err!=nil { _=writePanic("security canary missing or unreadable"); os.Exit(2) }
		if current!=baseline {
			_ = writePanic("bridger.key integrity changed")
			os.Exit(3)
		}
	}
}
