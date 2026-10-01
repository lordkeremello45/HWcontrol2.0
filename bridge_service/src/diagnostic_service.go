package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"time"
)
var diagnosticEvents atomic.Uint64
func recordSecurityDiagnostic(event,detail string){diagnosticEvents.Add(1);log.Printf("SECURITY_EVENT event=%s detail=%s",sanitizeDiagnostic(event),sanitizeDiagnostic(detail))}
func recordDiagnostic(event,detail string){diagnosticEvents.Add(1);log.Printf("DIAGNOSTIC_EVENT event=%s detail=%s",sanitizeDiagnostic(event),sanitizeDiagnostic(detail))}
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
