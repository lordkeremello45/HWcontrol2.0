package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFetchStatusCanaryTriggersPanicOnModification(t *testing.T) {
	dir:=t.TempDir()
	t.Setenv("HWCONTROL_DECOY_DIR",dir)
	t.Setenv("HWCONTROL_PANIC_FILE",filepath.Join(dir,"panic-mode.json"))
	decoyService=fetchStatusService{}
	if err:=initializeDecoyService();err!=nil{t.Fatal(err)}
	if panicModeActive(){t.Fatal("panic mode unexpectedly active")}
	if err:=os.WriteFile(decoyPath(),[]byte("tampered\n"),0600);err!=nil{t.Fatal(err)}
	checkDecoyIntegrity()
	if !panicModeActive(){t.Fatal("canary modification did not trigger panic mode")}
	if !decoyService.triggered{t.Fatal("canary service was not triggered")}
}

func TestFetchStatusCanaryIsNonSecret(t *testing.T) {
	dir:=t.TempDir();t.Setenv("HWCONTROL_DECOY_DIR",dir)
	if err:=ensureDecoyFile();err!=nil{t.Fatal(err)}
	data,err:=os.ReadFile(decoyPath());if err!=nil{t.Fatal(err)}
	if len(data)==0{t.Fatal("empty canary")}
}
