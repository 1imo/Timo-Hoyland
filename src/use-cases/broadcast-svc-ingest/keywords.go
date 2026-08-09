package ingest

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"timohoyland.co.uk/utils"
)

// Keywords generates and merges article keywords (defaults + AI + extras) at ingest time.
type Keywords struct {
	AI           *utils.AIClient
	AssetsDir    string
	defaults     []string
	systemPrompt string
}

func NewKeywords(ai *utils.AIClient, assetsDir string) (*Keywords, error) {
	k := &Keywords{AI: ai, AssetsDir: assetsDir}
	defPath := filepath.Join(assetsDir, "prompts", "default-keywords.txt")
	if raw, err := os.ReadFile(defPath); err == nil {
		k.defaults = splitKeywords(string(raw))
	}
	promptPath := filepath.Join(assetsDir, "prompts", "article-keywords.md")
	raw, err := os.ReadFile(promptPath)
	if err != nil {
		return nil, fmt.Errorf("read keyword prompt: %w", err)
	}
	k.systemPrompt = strings.TrimSpace(string(raw))
	return k, nil
}

func (k *Keywords) Defaults() []string {
	if k == nil {
		return nil
	}
	return append([]string(nil), k.defaults...)
}

func (k *Keywords) Build(ctx context.Context, title, body string, extras []string) ([]string, error) {
	aiList := []string{}
	if k != nil && k.AI != nil && k.AI.Enabled() {
		user := fmt.Sprintf("Title: %s\n\n%s", title, body)
		out, err := k.AI.Chat(ctx, k.systemPrompt, user)
		if err != nil {
			return nil, err
		}
		aiList = splitKeywords(out)
	}
	return mergeKeywords(k.Defaults(), extras, aiList), nil
}

func splitKeywords(raw string) []string {
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	seen := map[string]struct{}{}
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		key := strings.ToLower(p)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, p)
	}
	return out
}

func mergeKeywords(lists ...[]string) []string {
	seen := map[string]struct{}{}
	var out []string
	for _, list := range lists {
		for _, k := range list {
			k = strings.TrimSpace(k)
			if k == "" {
				continue
			}
			key := strings.ToLower(k)
			if _, ok := seen[key]; ok {
				continue
			}
			seen[key] = struct{}{}
			out = append(out, k)
		}
	}
	return out
}
