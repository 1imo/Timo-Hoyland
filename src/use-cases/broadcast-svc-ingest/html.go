package ingest

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"timohoyland.co.uk/utils"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/renderer/html"
)

// HTMLRenderer builds SEO-oriented article body HTML via AI at ingest (goldmark fallback).
type HTMLRenderer struct {
	AI           *utils.AIClient
	systemPrompt string
	md           goldmark.Markdown
}

func NewHTMLRenderer(ai *utils.AIClient, assetsDir string) (*HTMLRenderer, error) {
	h := &HTMLRenderer{
		AI: ai,
		md: goldmark.New(
			goldmark.WithExtensions(extension.Table, extension.Linkify),
			goldmark.WithRendererOptions(html.WithUnsafe()),
		),
	}
	promptPath := filepath.Join(assetsDir, "prompts", "article-html.md")
	raw, err := os.ReadFile(promptPath)
	if err != nil {
		return nil, fmt.Errorf("read html prompt: %w", err)
	}
	h.systemPrompt = strings.TrimSpace(string(raw))
	return h, nil
}

// Render uses AI when configured; falls back to markdown on failure/empty.
func (h *HTMLRenderer) Render(ctx context.Context, title, content string) (string, error) {
	content = strings.TrimSpace(content)
	if content == "" {
		return "", nil
	}
	if h != nil && h.AI != nil && h.AI.Enabled() {
		user := fmt.Sprintf("Title: %s\n\n%s", title, content)
		out, err := h.AI.Chat(ctx, h.systemPrompt, user)
		if err == nil {
			if cleaned := cleanAIHTML(out); cleaned != "" {
				return cleaned, nil
			}
		}
	}
	return h.fallbackMarkdown(content)
}

func (h *HTMLRenderer) fallbackMarkdown(content string) (string, error) {
	var buf bytes.Buffer
	if err := h.md.Convert([]byte(strings.TrimSpace(content)), &buf); err != nil {
		return "", fmt.Errorf("rendering markdown: %w", err)
	}
	return buf.String(), nil
}

func cleanAIHTML(raw string) string {
	s := strings.TrimSpace(raw)
	s = strings.TrimPrefix(s, "```html")
	s = strings.TrimPrefix(s, "```HTML")
	s = strings.TrimPrefix(s, "```")
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}
