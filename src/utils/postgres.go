package utils

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Postgres struct {
	Pool *pgxpool.Pool
}

func OpenPostgres(ctx context.Context, databaseURL string) (*Postgres, error) {
	if databaseURL == "" {
		return nil, fmt.Errorf("DB_URL is required")
	}
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, err
	}
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return &Postgres{Pool: pool}, nil
}

func (p *Postgres) Close() {
	if p != nil && p.Pool != nil {
		p.Pool.Close()
	}
}

// ArticleRow is the persisted article shape.
// Slug / meta description / excerpt are derived at runtime from title + content.
type ArticleRow struct {
	Title     string
	Keywords  []string
	Content   string
	HTML      string
	Views     int
	CreatedAt time.Time
	UpdatedAt time.Time
}

func (p *Postgres) ListArticles(ctx context.Context) ([]ArticleRow, error) {
	rows, err := p.Pool.Query(ctx, `
		SELECT title, keywords, content, html, views, created_at, updated_at
		FROM article
		ORDER BY updated_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []ArticleRow
	for rows.Next() {
		a, err := scanArticle(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (p *Postgres) UpsertArticle(ctx context.Context, a ArticleRow) error {
	if a.Keywords == nil {
		a.Keywords = []string{}
	}
	kw, err := json.Marshal(a.Keywords)
	if err != nil {
		return err
	}
	created := a.CreatedAt
	updated := a.UpdatedAt
	if created.IsZero() {
		created = time.Now().UTC()
	}
	if updated.IsZero() {
		updated = created
	}
	_, err = p.Pool.Exec(ctx, `
		INSERT INTO article (title, keywords, content, html, created_at, updated_at)
		VALUES ($1, $2::jsonb, $3, $4, $5, $6)
		ON CONFLICT (title) DO UPDATE SET
			keywords = EXCLUDED.keywords,
			content = EXCLUDED.content,
			html = EXCLUDED.html,
			updated_at = EXCLUDED.updated_at
	`, a.Title, string(kw), a.Content, a.HTML, created, updated)
	return err
}

// IncrementArticleViews bumps views for the given title (does not touch updated_at).
func (p *Postgres) IncrementArticleViews(ctx context.Context, title string) error {
	tag, err := p.Pool.Exec(ctx, `
		UPDATE article SET views = views + 1 WHERE title = $1
	`, title)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("article not found")
	}
	return nil
}

type scannable interface {
	Scan(dest ...any) error
}

func scanArticle(row scannable) (ArticleRow, error) {
	var a ArticleRow
	var kw []byte
	if err := row.Scan(&a.Title, &kw, &a.Content, &a.HTML, &a.Views, &a.CreatedAt, &a.UpdatedAt); err != nil {
		return ArticleRow{}, err
	}
	if len(kw) > 0 {
		if err := json.Unmarshal(kw, &a.Keywords); err != nil {
			return ArticleRow{}, fmt.Errorf("keywords json: %w", err)
		}
	}
	if a.Keywords == nil {
		a.Keywords = []string{}
	}
	return a, nil
}
