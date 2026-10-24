// Package healthycore provides conservative, evidence-based CPU/GPU/RAM condition
// assessment. It does not claim to measure physical component wear or remaining life.
package healthycore

import (
	"errors"
	"fmt"
	"math"
)

type DeviceKind string

const (
	CPU DeviceKind = "cpu"
	GPU DeviceKind = "gpu"
	RAM DeviceKind = "ram"
)

type Evidence struct {
	Device                DeviceKind
	SampleCount           int
	MaxTemperatureC       *float64
	ThermalLimitC         *float64
	ThermalThrottleEvents int
	ObservedErrors        int
	// VendorHealthPercent is optional and must come from a trusted, device-specific
	// health source. It is not inferred from temperature or utilization.
	VendorHealthPercent *float64
	// MemoryUsagePercent is contextual telemetry only; utilization is not RAM health.
	MemoryUsagePercent *float64
}

type Assessment struct {
	Device          DeviceKind `json:"device"`
	ConditionIndex  *int       `json:"condition_index"`
	Status          string     `json:"status"`
	Confidence      string     `json:"confidence"`
	EvidenceSummary []string   `json:"evidence_summary"`
	Limitations     []string   `json:"limitations"`
}

var ErrInvalidEvidence = errors.New("invalid Healthy Core evidence")

// Evaluate computes a transparent condition index from supplied evidence.
// The index is an operational indicator, not a percent of physical wear.
// Missing or contradictory measurements are rejected or reported as unknown.
func Evaluate(e Evidence) (Assessment, error) {
	if e.Device != CPU && e.Device != GPU && e.Device != RAM {
		return Assessment{}, fmt.Errorf("%w: unsupported device %q", ErrInvalidEvidence, e.Device)
	}
	if e.SampleCount < 0 || e.ThermalThrottleEvents < 0 || e.ObservedErrors < 0 {
		return Assessment{}, fmt.Errorf("%w: counts must be non-negative", ErrInvalidEvidence)
	}
	if err := validPercent(e.VendorHealthPercent); err != nil {
		return Assessment{}, err
	}
	if e.MaxTemperatureC != nil && (!finite(*e.MaxTemperatureC) || *e.MaxTemperatureC < -20 || *e.MaxTemperatureC > 200) {
		return Assessment{}, fmt.Errorf("%w: implausible maximum temperature", ErrInvalidEvidence)
	}
	if e.ThermalLimitC != nil && (!finite(*e.ThermalLimitC) || *e.ThermalLimitC <= 0 || *e.ThermalLimitC > 200) {
		return Assessment{}, fmt.Errorf("%w: invalid thermal limit", ErrInvalidEvidence)
	}
	if e.Device == RAM && e.MaxTemperatureC != nil {
		return Assessment{}, fmt.Errorf("%w: RAM does not use CPU/GPU thermal scoring", ErrInvalidEvidence)
	}
	if e.MaxTemperatureC != nil && e.ThermalLimitC == nil {
		return Assessment{}, fmt.Errorf("%w: temperature requires a device-specific thermal limit", ErrInvalidEvidence)
	}
	if e.MaxTemperatureC != nil && e.ThermalLimitC != nil && *e.MaxTemperatureC > *e.ThermalLimitC+15 {
		return Assessment{}, fmt.Errorf("%w: temperature is inconsistent with the supplied thermal limit", ErrInvalidEvidence)
	}

	result := Assessment{
		Device:          e.Device,
		Status:          "insufficient_data",
		Confidence:      "low",
		EvidenceSummary: []string{},
		Limitations: []string{
			"This index is not a physical-wear percentage or a remaining-life estimate.",
			"Results depend on the quality, duration, and device-specific meaning of supplied telemetry.",
			"No hardware settings are changed by this assessment.",
		},
	}
	// No live samples and no vendor health report means there is no basis for a score.
	if (e.Device == RAM || e.MaxTemperatureC == nil || e.SampleCount == 0) && e.VendorHealthPercent == nil && e.ObservedErrors == 0 && e.ThermalThrottleEvents == 0 {
		result.ConditionIndex = nil
		result.EvidenceSummary = append(result.EvidenceSummary, "No usable health evidence was supplied.")
		return result, nil
	}

	score := 100
	indicators := 0
	if e.Device != RAM && e.MaxTemperatureC != nil && e.ThermalLimitC != nil && e.SampleCount > 0 {
		ratio := *e.MaxTemperatureC / *e.ThermalLimitC
		switch {
		case ratio >= 1:
			score -= 35
			result.EvidenceSummary = append(result.EvidenceSummary, "Maximum observed temperature reached or exceeded the supplied thermal limit.")
		case ratio >= 0.95:
			score -= 25
			result.EvidenceSummary = append(result.EvidenceSummary, "Maximum observed temperature was within 5% of the supplied thermal limit.")
		case ratio >= 0.85:
			score -= 12
			result.EvidenceSummary = append(result.EvidenceSummary, "Maximum observed temperature was high relative to the supplied thermal limit.")
		default:
			result.EvidenceSummary = append(result.EvidenceSummary, "Maximum observed temperature was below 85% of the supplied thermal limit.")
		}
		indicators++
	}
	if e.Device != RAM && e.ThermalThrottleEvents > 0 {
		penalty := e.ThermalThrottleEvents * 5
		if penalty > 20 {
			penalty = 20
		}
		score -= penalty
		result.EvidenceSummary = append(result.EvidenceSummary, fmt.Sprintf("%d thermal-throttling event(s) were reported.", e.ThermalThrottleEvents))
		indicators++
	}
	if e.ObservedErrors > 0 {
		penaltyPerError := 10
		if e.Device == RAM {
			penaltyPerError = 20
		}
		penalty := e.ObservedErrors * penaltyPerError
		if penalty > 30 {
			penalty = 30
		}
		score -= penalty
		result.EvidenceSummary = append(result.EvidenceSummary, fmt.Sprintf("%d hardware/driver error(s) were reported.", e.ObservedErrors))
		indicators++
	}
	if e.Device == RAM && e.MemoryUsagePercent != nil {
		result.EvidenceSummary = append(result.EvidenceSummary, fmt.Sprintf("Current RAM utilization is %.1f%%; utilization is not a RAM health or wear measurement.", *e.MemoryUsagePercent))
	}
	if e.VendorHealthPercent != nil {
		vendorScore := int(math.Round(*e.VendorHealthPercent))
		// A trusted device-specific report is authoritative evidence for this
		// dimension, but not proof of CPU/GPU remaining lifespan.
		score = (score + vendorScore) / 2
		result.EvidenceSummary = append(result.EvidenceSummary, "A device-specific vendor health percentage was supplied.")
		indicators++
	}
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	result.ConditionIndex = &score
	if indicators >= 2 && e.SampleCount >= 12 {
		result.Confidence = "medium"
	}
	switch {
	case score >= 85:
		result.Status = "no_obvious_concern"
	case score >= 65:
		result.Status = "needs_attention"
	default:
		result.Status = "elevated_risk"
	}
	if e.Device == RAM && e.ObservedErrors == 0 && e.VendorHealthPercent == nil {
		result.ConditionIndex = nil
		result.Status = "insufficient_data"
		result.Confidence = "low"
		result.EvidenceSummary = append(result.EvidenceSummary, "RAM utilization alone cannot establish module health; hardware/ECC error telemetry or a trusted device-specific health report is required.")
		return result, nil
	}
	if e.SampleCount < 12 && e.VendorHealthPercent == nil {
		result.EvidenceSummary = append(result.EvidenceSummary, "A short observation window limits confidence; collect more samples.")
	}
	return result, nil
}

func validPercent(value *float64) error {
	if value != nil && (!finite(*value) || *value < 0 || *value > 100) {
		return fmt.Errorf("%w: vendor health percentage must be between 0 and 100", ErrInvalidEvidence)
	}
	return nil
}

func finite(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) }
