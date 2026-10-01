package main

import "testing"

func TestServiceCatalogContainsSixSecurityBoundedServices(t *testing.T) {
	expected := map[string]bool{
		"update": false,
		"sensorhealth": false,
		"diagnostics": false,
		"game": false,
		"security": false,
		"fetch-status": false,
	}
	for _, service := range hwcontrolServices {
		if _, ok := expected[service.Name]; !ok {
			t.Fatalf("unexpected service %q in catalog", service.Name)
		}
		expected[service.Name] = true
	}
	for name, found := range expected {
		if !found {
			t.Fatalf("required service %q missing from catalog", name)
		}
	}
	if len(hwcontrolServices) != 6 {
		t.Fatalf("service catalog contains %d services, want 6", len(hwcontrolServices))
	}
	if hwcontrolServices[4].Name != "security" || !hwcontrolServices[4].FailClosed {
		t.Fatal("security service must be a fail-closed secondary shield")
	}
	if hwcontrolServices[5].Name != "fetch-status" || !hwcontrolServices[5].FailClosed {
		t.Fatal("fetch-status service must be a fail-closed canary")
	}
}
