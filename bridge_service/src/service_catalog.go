package main

import "time"

type HWControlService struct {
	Name string
	Version string
	Role string
	Trust string
	Network bool
	FailClosed bool
}

var hwcontrolServices = []HWControlService{
	{Name:"update", Version:"1", Role:"release/update metadata and integrity verification", Trust:"unprivileged metadata", Network:true, FailClosed:true},
	{Name:"sensorhealth", Version:"1", Role:"normalized sensor health and safety state", Trust:"hardware telemetry", Network:false, FailClosed:true},
	{Name:"diagnostics", Version:"1", Role:"local crash/error/security diagnostics", Trust:"local event data", Network:false, FailClosed:false},
	{Name:"game", Version:"1", Role:"Game Mode detection and profile state", Trust:"user/application state", Network:false, FailClosed:true},
	{Name:"security", Version:"1", Role:"secondary security guardian and panic-state enforcement", Trust:"secondary security boundary", Network:false, FailClosed:true},
	{Name:"fetch-status", Version:"1", Role:"decoy/canary integrity monitor", Trust:"untrusted touch signal", Network:false, FailClosed:true},
}

func serviceCatalogSnapshot() []map[string]any {
	out:=make([]map[string]any,0,len(hwcontrolServices))
	for _,s:=range hwcontrolServices {
		out=append(out,map[string]any{"name":s.Name,"version":s.Version,"role":s.Role,"trust":s.Trust,"network":s.Network,"failClosed":s.FailClosed})
	}
	return out
}
var serviceStartedAt=time.Now()
func serviceUptimeSeconds() int64 { return int64(time.Since(serviceStartedAt).Seconds()) }
