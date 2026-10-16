package healthycore

import (
	"math"
	"testing"
)

func ptr(v float64) *float64 { return &v }

func TestNoEvidenceIsUnknownNotPerfect(t *testing.T) {
	got, err := Evaluate(Evidence{Device: CPU})
	if err != nil { t.Fatal(err) }
	if got.ConditionIndex != nil || got.Status != "insufficient_data" {
		t.Fatalf("expected unknown result, got %#v", got)
	}
}

func TestTemperatureWithoutSamplesRemainsUnknown(t *testing.T) {
	got, err := Evaluate(Evidence{Device: CPU, MaxTemperatureC: ptr(60), ThermalLimitC: ptr(100)})
	if err != nil { t.Fatal(err) }
	if got.ConditionIndex != nil || got.Status != "insufficient_data" {
		t.Fatalf("temperature without a sample count must remain unknown, got %#v", got)
	}
}

func TestSamplesWithoutSignalsRemainUnknown(t *testing.T) {
	got, err := Evaluate(Evidence{Device: GPU, SampleCount: 120})
	if err != nil { t.Fatal(err) }
	if got.ConditionIndex != nil || got.Status != "insufficient_data" {
		t.Fatalf("sample count alone must not imply health, got %#v", got)
	}
}

func TestCoolStableTelemetryProducesConditionIndex(t *testing.T) {
	got, err := Evaluate(Evidence{
		Device: CPU, SampleCount: 60,
		MaxTemperatureC: ptr(65), ThermalLimitC: ptr(100),
	})
	if err != nil { t.Fatal(err) }
	if got.ConditionIndex == nil || *got.ConditionIndex != 100 {
		t.Fatalf("unexpected index: %#v", got.ConditionIndex)
	}
	if got.Confidence != "low" {
		t.Fatalf("one indicator must not claim medium confidence, got %q", got.Confidence)
	}
}

func TestThermalStressAndErrorsReduceIndex(t *testing.T) {
	got, err := Evaluate(Evidence{
		Device: GPU, SampleCount: 60,
		MaxTemperatureC: ptr(97), ThermalLimitC: ptr(100),
		ThermalThrottleEvents: 2, ObservedErrors: 1,
	})
	if err != nil { t.Fatal(err) }
	if got.ConditionIndex == nil || *got.ConditionIndex >= 100 || got.Status != "elevated_risk" {
		t.Fatalf("expected reduced index and attention status, got %#v", got)
	}
}

func TestRAMUtilizationAloneDoesNotClaimHealth(t *testing.T) {
	got, err := Evaluate(Evidence{Device: RAM, SampleCount: 120, MemoryUsagePercent: ptr(42)})
	if err != nil { t.Fatal(err) }
	if got.ConditionIndex != nil || got.Status != "insufficient_data" {
		t.Fatalf("RAM utilization alone must not imply health, got %#v", got)
	}
}

func TestRAMHardwareErrorsProduceConditionAssessment(t *testing.T) {
	got, err := Evaluate(Evidence{Device: RAM, ObservedErrors: 1, MemoryUsagePercent: ptr(88)})
	if err != nil { t.Fatal(err) }
	if got.ConditionIndex == nil || *got.ConditionIndex >= 100 || got.Status != "needs_attention" {
		t.Fatalf("expected RAM errors to lower condition index, got %#v", got)
	}
}

func TestRAMRejectsCPUAndGPUTemperatureEvidence(t *testing.T) {
	_, err := Evaluate(Evidence{Device: RAM, SampleCount: 10, MaxTemperatureC: ptr(60), ThermalLimitC: ptr(100)})
	if err == nil { t.Fatal("RAM must not use CPU/GPU thermal scoring") }
}

func TestVendorHealthIsValidated(t *testing.T) {
	_, err := Evaluate(Evidence{Device: GPU, VendorHealthPercent: ptr(101)})
	if err == nil { t.Fatal("expected out-of-range vendor health to be rejected") }
	_, err = Evaluate(Evidence{Device: GPU, VendorHealthPercent: ptr(math.NaN())})
	if err == nil { t.Fatal("expected NaN vendor health to be rejected") }
}

func TestTemperatureRequiresDeviceLimit(t *testing.T) {
	_, err := Evaluate(Evidence{Device: CPU, SampleCount: 10, MaxTemperatureC: ptr(70)})
	if err == nil { t.Fatal("expected missing thermal limit to be rejected") }
}

func TestCountsCannotBeNegative(t *testing.T) {
	_, err := Evaluate(Evidence{Device: CPU, ObservedErrors: -1})
	if err == nil { t.Fatal("expected negative count to be rejected") }
}
