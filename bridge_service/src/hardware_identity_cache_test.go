package main

import (
	"sync/atomic"
	"testing"
	"time"
)

func TestHardwareIdentityCacheReturnsImmediatelyAndRefreshesInBackground(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	var calls atomic.Int32
	cache := newHardwareIdentityCache(func() HardwareIdentity {
		calls.Add(1)
		close(started)
		<-release
		return HardwareIdentity{
			SystemModel:     "Test machine",
			DetectionSource: "test",
			DetectionStatus: "ok",
		}
	})

	first := cache.get()
	if first.DetectionStatus != "pending" {
		t.Fatalf("cold cache status = %q, want pending", first.DetectionStatus)
	}
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("identity collection did not start asynchronously")
	}
	second := cache.get()
	if second.DetectionStatus != "pending" {
		t.Fatalf("cache should remain nonblocking while collection runs, got %q", second.DetectionStatus)
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("collector calls = %d, want exactly one in-flight call", got)
	}

	close(release)
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		identity := cache.get()
		if identity.DetectionStatus == "ok" {
			if identity.SystemModel != "Test machine" {
				t.Fatalf("cached system model = %q", identity.SystemModel)
			}
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("completed identity result was not published to cache")
}

func TestHardwareIdentityCacheRetriesPartialResults(t *testing.T) {
	var calls atomic.Int32
	cache := newHardwareIdentityCache(func() HardwareIdentity {
		calls.Add(1)
		return HardwareIdentity{DetectionStatus: "partial"}
	})
	_ = cache.get()
	deadline := time.Now().Add(time.Second)
	for {
		cache.mu.Lock()
		updated := !cache.updatedAt.IsZero()
		cache.mu.Unlock()
		if updated || time.Now().After(deadline) {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}
	if calls.Load() != 1 {
		t.Fatalf("initial collector calls = %d, want 1", calls.Load())
	}
	cache.mu.Lock()
	cache.nextRefresh = time.Now().Add(-time.Second)
	cache.mu.Unlock()
	_ = cache.get()
	deadline = time.Now().Add(time.Second)
	for calls.Load() < 2 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	if calls.Load() != 2 {
		t.Fatalf("partial identity was not retried: collector calls = %d", calls.Load())
	}
}
