package ingest

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"timohoyland.co.uk/use-cases/view"
	"timohoyland.co.uk/utils"
)

// Job is the payload from broadcast-svc.
type Job struct {
	ID         string   `json:"id"`
	Text       string   `json:"text"`
	HTML       string   `json:"html"`
	ParseMode  string   `json:"parse_mode"`
	FromUserID string   `json:"from_user_id"`
	CreatedAt  string   `json:"created_at"`
	Source     string   `json:"source"`
	Services   []string `json:"services"`
}

// UseCase turns a broadcast-svc queue payload into a stored article (AI keywords + HTML).
type UseCase struct {
	Articles *view.Articles
	Keywords *Keywords
	HTML     *HTMLRenderer
}

func New(articles *view.Articles, keywords *Keywords, html *HTMLRenderer) *UseCase {
	return &UseCase{Articles: articles, Keywords: keywords, HTML: html}
}

// HandlePayload parses job JSON, enriches with AI, and upserts the article.
func (u *UseCase) HandlePayload(ctx context.Context, payload string) error {
	var job Job
	if err := json.Unmarshal([]byte(payload), &job); err != nil {
		return fmt.Errorf("decode job: %w", err)
	}
	title, body := splitTitleBody(job)
	if title == "" {
		return fmt.Errorf("job %s: empty title (first line required)", job.ID)
	}
	return u.ingest(ctx, title, body, nil)
}

func (u *UseCase) ingest(ctx context.Context, title, content string, seedKeywords []string) error {
	title = strings.TrimSpace(title)
	if title == "" {
		return fmt.Errorf("title required")
	}
	if view.Slugify(title) == "" {
		return fmt.Errorf("invalid title for slug")
	}
	content = strings.TrimSpace(content)

	kw, err := u.Keywords.Build(ctx, title, content, seedKeywords)
	if err != nil {
		kw = mergeKeywords(u.Keywords.Defaults(), seedKeywords)
	}
	html, err := u.HTML.Render(ctx, title, content)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	return u.Articles.Upsert(ctx, utils.ArticleRow{
		Title:     title,
		Keywords:  kw,
		Content:   content,
		HTML:      html,
		CreatedAt: now,
		UpdatedAt: now,
	})
}

func splitTitleBody(job Job) (title, plain string) {
	raw := strings.TrimSpace(job.Text)
	if raw == "" {
		raw = stripTags(job.HTML)
	}
	first, rest, _ := strings.Cut(raw, "\n")
	return strings.TrimSpace(first), strings.TrimSpace(rest)
}

func stripTags(s string) string {
	var b strings.Builder
	inTag := false
	for _, r := range s {
		switch {
		case r == '<':
			inTag = true
		case r == '>':
			inTag = false
		case !inTag:
			b.WriteRune(r)
		}
	}
	return strings.TrimSpace(b.String())
}
