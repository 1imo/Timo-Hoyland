package view

import (
	"context"
	"fmt"
	"strings"

	"timohoyland.co.uk/utils"
)

// Views increments per-article view counts (DB).
type Views struct {
	DB       *utils.Postgres
	Articles *Articles
}

func NewViews(db *utils.Postgres, articles *Articles) *Views {
	return &Views{DB: db, Articles: articles}
}

// Increment looks up the article by slug and bumps its views counter.
func (v *Views) Increment(ctx context.Context, slug string) error {
	slug = strings.TrimSpace(slug)
	if slug == "" {
		return fmt.Errorf("slug required")
	}
	art, ok := v.Articles.BySlug(slug)
	if !ok {
		return ErrNotFound
	}
	return v.DB.IncrementArticleViews(ctx, art.Title)
}

// ErrNotFound means no article matches the slug.
var ErrNotFound = fmt.Errorf("article not found")
