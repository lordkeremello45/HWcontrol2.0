package main

import (
	"math"
	"testing"
)

func TestValidateFanPercent(t *testing.T) {
	for _, value := range []float64{1, 25, 100} {
		if err := validateFanPercent(value); err != nil {
			t.Fatalf("expected %v to be accepted: %v", value, err)
		}
	}
	for _, value := range []float64{-1, 0, 101, math.NaN(), math.Inf(1)} {
		if err := validateFanPercent(value); err == nil {
			t.Fatalf("expected %v to be rejected", value)
		}
	}
}
