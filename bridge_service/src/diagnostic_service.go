package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync/atomic"
	"time"
)
var diagnosticEvents atomic.Uint64

func diagnosticRecordPath() string {
	if configured := strings.TrimSpace(os.Getenv("HWCONTROL_DIAGNOSTIC_LOG")); configured != "" {
		return configured
	}
	switch runtime.GOOS {
	case "windows":
		root := os.Getenv("ProgramData")
		if root == "" { root = `C:\ProgramData` }
		return filepath.Join(root, "HWControl", "diagnostics", "events.jsonl")
	case "darwin":
		return filepath.Join("/Library", "Application Support", "HWControl", "diagnostics", "events.jsonl")
	default:
		return "/var/lib/hwcontrol/diagnostics/events.jsonl"
	}
}

func recordSecurityDiagnostic(event,detail string){
	diagnosticEvents.Add(1)
	event=sanitizeDiagnostic(event); detail=sanitizeDiagnostic(detail)
	log.Printf("SECURITY_EVENT event=%s detail=%s",event,detail)
	_ = appendCrashRecord(diagnosticRecordPath(), event+": "+detail)
}
func recordDiagnostic(event,detail string){
	diagnosticEvents.Add(1)
	event=sanitizeDiagnostic(event); detail=sanitizeDiagnostic(detail)
	log.Printf("DIAGNOSTIC_EVENT event=%s detail=%s",event,detail)
	_ = appendCrashRecord(diagnosticRecordPath(), event+": "+detail)
}
func sanitizeDiagnostic(v string)string{v=strings.ReplaceAll(v,"\r"," ");v=strings.ReplaceAll(v,"\n"," ");if len(v)>512{return v[:512]};return v}
func diagnosticServiceSnapshot()map[string]any{return map[string]any{"eventCount":diagnosticEvents.Load(),"localOnly":true}}
func appendCrashRecord(path,event string)error{
	if strings.TrimSpace(path)==""{return nil}
	if err:=os.MkdirAll(filepath.Dir(path),0700);err!=nil{return err}
	p:=map[string]any{"timestamp":time.Now().UTC().Format(time.RFC3339Nano),"event":sanitizeDiagnostic(event)}
	data,err:=json.Marshal(p);if err!=nil{return err}
	f,err:=os.OpenFile(path,os.O_CREATE|os.O_APPEND|os.O_WRONLY,0600);if err!=nil{return err}
	defer f.Close();_,err=f.Write(append(data,'\n'));return err
}
