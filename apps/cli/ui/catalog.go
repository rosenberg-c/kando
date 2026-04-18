package ui

import (
	"embed"
	"encoding/json"
	"sync"
)

//go:embed strings/en/common.json
var stringsFS embed.FS

var (
	loadOnce sync.Once
	messages map[string]string
)

func T(key string) string {
	loadOnce.Do(load)
	if value, ok := messages[key]; ok {
		return value
	}

	return key
}

func load() {
	messages = map[string]string{}
	payload, err := stringsFS.ReadFile("strings/en/common.json")
	if err != nil {
		return
	}

	_ = json.Unmarshal(payload, &messages)
}
