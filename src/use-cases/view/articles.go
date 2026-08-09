package view

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"sync"
	"time"

	"timohoyland.co.uk/utils"

	"github.com/yuin/goldmark"
)

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

// Article is the in-memory / template-facing article.
// Slug, Description, and Excerpt are derived from Title/Content — not stored.
type Article struct {
	Title          string
	Slug           string
	Description    string
	Keywords       string
	KeywordList    []string
	Body           string
	Content        string
	Excerpt        string
	Views          int
	Created        string
	Updated        string
	DisplayUpdated string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// Articles is the in-memory article cache backed by Postgres (read path).
type Articles struct {
	DB *utils.Postgres
	md goldmark.Markdown

	mu     sync.RWMutex
	list   []Article
	bySlug map[string]Article
}

func NewArticles(db *utils.Postgres) *Articles {
	return &Articles{
		DB:     db,
		md:     newMarkdown(),
		bySlug: map[string]Article{},
	}
}

func (a *Articles) Reload(ctx context.Context) error {
	rows, err := a.DB.ListArticles(ctx)
	if err != nil {
		return err
	}
	list := make([]Article, 0, len(rows))
	bySlug := make(map[string]Article, len(rows))
	for _, row := range rows {
		art, err := a.fromRow(row)
		if err != nil {
			return err
		}
		list = append(list, art)
		bySlug[art.Slug] = art
	}
	a.mu.Lock()
	a.list = list
	a.bySlug = bySlug
	a.mu.Unlock()
	return nil
}

func (a *Articles) List() []Article {
	a.mu.RLock()
	defer a.mu.RUnlock()
	out := make([]Article, len(a.list))
	copy(out, a.list)
	return out
}

func (a *Articles) BySlug(slug string) (Article, bool) {
	a.mu.RLock()
	defer a.mu.RUnlock()
	art, ok := a.bySlug[slug]
	return art, ok
}

// Upsert persists a fully enriched row and reloads the in-memory cache.
func (a *Articles) Upsert(ctx context.Context, row utils.ArticleRow) error {
	if err := a.DB.UpsertArticle(ctx, row); err != nil {
		return err
	}
	return a.Reload(ctx)
}

func (a *Articles) fromRow(row utils.ArticleRow) (Article, error) {
	body := strings.TrimSpace(row.HTML)
	if body == "" {
		rendered, err := renderMarkdown(a.md, row.Content)
		if err != nil {
			return Article{}, err
		}
		body = rendered
	}
	excerpt := truncateRunes(row.Content, 255)
	created := row.CreatedAt.UTC().Format("2006-01-02")
	updated := row.UpdatedAt.UTC().Format("2006-01-02")
	return Article{
		Title:          row.Title,
		Slug:           Slugify(row.Title),
		Description:    truncateRunes(row.Content, 160),
		Keywords:       joinKeywords(row.Keywords),
		KeywordList:    append([]string(nil), row.Keywords...),
		Body:           body,
		Content:        row.Content,
		Excerpt:        excerpt,
		Views:          row.Views,
		Created:        created,
		Updated:        updated,
		DisplayUpdated: formatHumanDate(row.UpdatedAt),
		CreatedAt:      row.CreatedAt,
		UpdatedAt:      row.UpdatedAt,
	}, nil
}

// Slugify lowercases and hyphenates a title for URL slugs.
func Slugify(title string) string {
	s := strings.ToLower(strings.TrimSpace(title))
	s = nonSlug.ReplaceAllString(s, "-")
	return strings.Trim(s, "-")
}

func truncateRunes(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	runes := []rune(s)
	if len(runes) <= n {
		return s
	}
	truncated := runes[:n]
	if i := strings.LastIndex(string(truncated), " "); i > n*3/4 {
		truncated = []rune(string(truncated)[:i])
	}
	return string(truncated) + "…"
}

func formatHumanDate(t time.Time) string {
	day := t.Day()
	var suffix string
	switch day {
	case 1, 21, 31:
		suffix = "st"
	case 2, 22:
		suffix = "nd"
	case 3, 23:
		suffix = "rd"
	default:
		suffix = "th"
	}
	return fmt.Sprintf("%d%s %s %d", day, suffix, t.Format("Jan"), t.Year())
}

func joinKeywords(list []string) string {
	return strings.Join(list, ", ")
}
