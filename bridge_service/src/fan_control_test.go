package main

import "testing"

func TestValidateFanPercent(t *testing.T) {
  for _, value := range []float64{0, 25, 100} {
    if err := validateFanPercent(value); err != nil {
      t.Fatalf("expected %v to be accepted: %v", value, err)
    }
  }
  for _, value := range []float64{-1, 101} {
    if err := validateFanPercent(value); err == nil {
      t.Fatalf("expected %v to be rejected", value)
    }
  }
}
