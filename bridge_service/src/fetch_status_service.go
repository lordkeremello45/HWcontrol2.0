package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
)
const decoyFileName="bridger.key"
const panicStateFileName="panic-mode.json"
type fetchStatusService struct{mu sync.Mutex;path string;baseline string;healthy bool;triggered bool;lastReason string}
var decoyService fetchStatusService
func decoyDirectory()string{
	if v:=strings.TrimSpace(os.Getenv("HWCONTROL_DECOY_DIR"));v!=""{return v}
	switch runtime.GOOS{
	case "windows":
		root:=os.Getenv("ProgramData");if root==""{root="C:\ProgramData"};return filepath.Join(root,"HWControl","security")
	case "darwin":return filepath.Join("/Library","Application Support","HWControl","security")
	default:return "/var/lib/hwcontrol/security"
	}
}
func panicStatePath()string{if v:=strings.TrimSpace(os.Getenv("HWCONTROL_PANIC_FILE"));v!=""{return v};return filepath.Join(decoyDirectory(),panicStateFileName)}
func decoyPath()string{return filepath.Join(decoyDirectory(),decoyFileName)}
func ensureDecoyFile()error{
	dir:=decoyDirectory();if err:=os.MkdirAll(dir,0700);err!=nil{return err}
	p:=decoyPath();if info,err:=os.Lstat(p);err==nil{if info.Mode()&os.ModeSymlink!=0||!info.Mode().IsRegular(){return fmt.Errorf("decoy is not a regular file")};return nil}else if !os.IsNotExist(err){return err}
	buf:=make([]byte,32);if _,err:=rand.Read(buf);err!=nil{return err}
	content:="HWCONTROL-DECOY-"+hex.EncodeToString(buf)+"\n"
	return os.WriteFile(p,[]byte(content),0600)
}
func decoyDigest(p string)(string,error){d,err:=os.ReadFile(p);if err!=nil{return "",err};h:=sha256.Sum256(d);return hex.EncodeToString(h[:]),nil}
func initializeDecoyService()error{
	if err:=ensureDecoyFile();err!=nil{return err};d,err:=decoyDigest(decoyPath());if err!=nil{return err}
	decoyService.mu.Lock();decoyService.path=decoyPath();decoyService.baseline=d;decoyService.healthy=true;decoyService.mu.Unlock();return nil
}
func checkDecoyIntegrity(){
	decoyService.mu.Lock();defer decoyService.mu.Unlock();if decoyService.path==""||decoyService.triggered{return}
	d,err:=decoyDigest(decoyService.path);if err!=nil{decoyService.triggered=true;decoyService.healthy=false;decoyService.lastReason="decoy missing or unreadable";triggerPanicModeLocked(decoyService.lastReason);return}
	if d!=decoyService.baseline{decoyService.triggered=true;decoyService.healthy=false;decoyService.lastReason="bridger.key integrity changed";triggerPanicModeLocked(decoyService.lastReason)}
}
func triggerPanicModeLocked(reason string){
	p:=map[string]any{"panic":true,"reason":sanitizeDiagnostic(reason),"timestamp":time.Now().UTC().Format(time.RFC3339Nano),"source":"fetch-status-canary"}
	data,err:=json.Marshal(p);if err!=nil{return};_ = os.MkdirAll(filepath.Dir(panicStatePath()),0700)
	tmp:=panicStatePath()+".tmp";if err:=os.WriteFile(tmp,append(data,'\n'),0600);err==nil{_ = os.Rename(tmp,panicStatePath())}
	recordSecurityDiagnostic("canary-triggered",reason)
}
func panicModeActive()bool{d,err:=os.ReadFile(panicStatePath());if err!=nil{return false};var s struct{Panic bool `json:"panic"`};return json.Unmarshal(d,&s)==nil&&s.Panic}
func clearPanicMode(){_ = os.Remove(panicStatePath())}
func fetchStatusSnapshot()map[string]any{decoyService.mu.Lock();defer decoyService.mu.Unlock();return map[string]any{"name":"fetch-status","canaryFile":decoyService.path,"canaryHealthy":decoyService.healthy,"triggered":decoyService.triggered,"panicMode":panicModeActive(),"lastReason":decoyService.lastReason,"readAccessMonitoring":"platform-audit-required"}}
