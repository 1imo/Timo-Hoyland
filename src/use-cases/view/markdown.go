package view

import (
	"bytes"
	"fmt"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/renderer/html"
)

// Local markdown→HTML for serving (legals + empty stored article html). No AI.
func newMarkdown() goldmark.Markdown {
	return goldmark.New(
		goldmark.WithExtensions(extension.Table, extension.Linkify),
		goldmark.WithRendererOptions(html.WithUnsafe()),
	)
}

func renderMarkdown(md goldmark.Markdown, src string) (string, error) {
	var buf bytes.Buffer
	if err := md.Convert([]byte(src), &buf); err != nil {
		return "", fmt.Errorf("rendering markdown: %w", err)
	}
	return buf.String(), nil
}
