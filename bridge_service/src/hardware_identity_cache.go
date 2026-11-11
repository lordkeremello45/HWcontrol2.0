package main

import (
	"sync"
	"time"
)

const (
	hardwareIdentityRefreshInterval = 30 * time.Minute
	hardwareIdentityRetryInterval   = time.Minute
)

type hardwareIdentityCache struct {
	mu          sync.Mutex
	collect     func() HardwareIdentity
	identity    HardwareIdentity
	updatedAt   time.Time
	nextRefresh time.Time
	refreshing  bool
}

func newHardwareIdentityCache(collect func() HardwareIdentity) *hardwareIdentityCache {
	return &hardwareIdentityCache{collect: collect}
}

// get returns immediately. A cold cache reports pending while the platform
// collector runs in the background; a warm cache remains available during
// refreshes so a slow WMI/sysfs helper cannot block Get Status.
func (cache *hardwareIdentityCache) get() HardwareIdentity {
	now := time.Now()
	cache.mu.Lock()
	if !cache.refreshing && (cache.updatedAt.IsZero() || !now.Before(cache.nextRefresh)) {
		cache.refreshing = true
		go cache.refresh()
	}
	identity := cache.identity
	cache.mu.Unlock()

	if identity.DetectionStatus == "" {
		identity = emptyHardwareIdentity()
		identity.DetectionSource = "background hardware identity discovery"
		identity.DetectionStatus = "pending"
	}
	return identity
}

func (cache *hardwareIdentityCache) refresh() {
	identity := cache.collect()
	now := time.Now()
	cache.mu.Lock()
	cache.identity = identity
	cache.updatedAt = now
	retry := hardwareIdentityRetryInterval
	if identity.DetectionStatus == "ok" {
		retry = hardwareIdentityRefreshInterval
	}
	cache.nextRefresh = now.Add(retry)
	cache.refreshing = false
	cache.mu.Unlock()
}

var runtimeHardwareIdentityCache = newHardwareIdentityCache(collectHardwareIdentity)

func cachedHardwareIdentity() HardwareIdentity {
	return runtimeHardwareIdentityCache.get()
}
