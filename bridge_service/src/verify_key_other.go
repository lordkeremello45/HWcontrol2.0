//go:build !windows

package main

import "fmt"

func verifyKeyPath() string {
	return ""
}

func loadOrCreateVerifyKey() ([]byte, error) {
	return nil, fmt.Errorf("Windows verify.key is not available on this platform")
}
