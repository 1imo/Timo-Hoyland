package main

import (
	"bytes"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"text/template"
	"time"

	"github.com/yuin/goldmark"
)

const baseURL = "https://timohoyland.co.uk"

type Article struct {
	Title          string
	Slug           string
	Description    string
	Keywords       string
	Theme          string
	Body           string
	Excerpt        string
	Created        string
	Updated        string
	DisplayUpdated string

	createdTime time.Time
	updatedTime time.Time
}

type IndexData struct {
	Articles []Article
	BaseURL  string
}

type ArticleData struct {
	Article
	BaseURL string
}

func main() {
	articles, err := loadArticles("articles")
	if err != nil {
		log.Fatalf("loading articles: %v", err)
	}

	tmplIndex, err := template.ParseFiles("templates/index.html.tmpl")
	if err != nil {
		log.Fatalf("parsing index template: %v", err)
	}
	tmplArticle, err := template.ParseFiles("templates/article.html.tmpl")
	if err != nil {
		log.Fatalf("parsing article template: %v", err)
	}
	tmplRobots, err := template.ParseFiles("templates/robots.txt.tmpl")
	if err != nil {
		log.Fatalf("parsing robots template: %v", err)
	}
	tmplSitemap, err := template.ParseFiles("templates/sitemap.xml.tmpl")
	if err != nil {
		log.Fatalf("parsing sitemap template: %v", err)
	}

	articleMap := make(map[string]Article)
	for _, a := range articles {
		articleMap[a.Slug] = a
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := tmplIndex.Execute(w, IndexData{Articles: articles, BaseURL: baseURL}); err != nil {
			log.Printf("executing index template: %v", err)
			http.Error(w, "Internal Server Error", 500)
		}
	})

	http.HandleFunc("/robots.txt", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		if err := tmplRobots.Execute(w, struct{ BaseURL string }{BaseURL: baseURL}); err != nil {
			log.Printf("executing robots template: %v", err)
			http.Error(w, "Internal Server Error", 500)
		}
	})

	http.HandleFunc("/sitemap.xml", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/xml; charset=utf-8")
		if err := tmplSitemap.Execute(w, IndexData{Articles: articles, BaseURL: baseURL}); err != nil {
			log.Printf("executing sitemap template: %v", err)
			http.Error(w, "Internal Server Error", 500)
		}
	})

	http.HandleFunc("/article/", func(w http.ResponseWriter, r *http.Request) {
		slug := strings.TrimPrefix(r.URL.Path, "/article/")
		if slug == "" {
			http.Redirect(w, r, "/", 302)
			return
		}
		article, ok := articleMap[slug]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := tmplArticle.Execute(w, ArticleData{Article: article, BaseURL: baseURL}); err != nil {
			log.Printf("executing article template: %v", err)
			http.Error(w, "Internal Server Error", 500)
		}
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	fmt.Printf("Serving at http://localhost:%s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func loadArticles(dir string) ([]Article, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	var articles []Article
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		path := filepath.Join(dir, e.Name())
		info, err := os.Stat(path)
		if err != nil {
			return nil, fmt.Errorf("stat %s: %w", path, err)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("reading %s: %w", path, err)
		}
		a, err := parseArticle(data)
		if err != nil {
			return nil, fmt.Errorf("parsing %s: %w", path, err)
		}
		if a.Created == "" {
			a.Created = info.ModTime().Format("2006-01-02")
		}
		if a.Updated == "" {
			a.Updated = info.ModTime().Format("2006-01-02")
		}
		if t, err := time.Parse("2006-01-02", a.Created); err == nil {
			a.createdTime = t
		}
		if t, err := time.Parse("2006-01-02", a.Updated); err == nil {
			a.updatedTime = t
			a.DisplayUpdated = formatHumanDate(t)
		}
		articles = append(articles, a)
	}
	sort.Slice(articles, func(i, j int) bool {
		return articles[i].updatedTime.After(articles[j].updatedTime)
	})
	return articles, nil
}

func parseArticle(data []byte) (Article, error) {
	parts := bytes.SplitN(data, []byte("\n---\n"), 2)
	if len(parts) != 2 {
		return Article{}, fmt.Errorf("missing frontmatter")
	}

	frontmatter := string(parts[0])
	bodyMarkdown := string(bytes.TrimSpace(parts[1]))

	// Simple YAML-like parsing for our fields
	var a Article
	lines := strings.Split(frontmatter, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || line == "---" {
			continue
		}
		if idx := strings.Index(line, ":"); idx > 0 {
			key := strings.TrimSpace(line[:idx])
			val := strings.TrimSpace(line[idx+1:])
			val = strings.Trim(val, `"`)
			switch key {
			case "title":
				a.Title = val
			case "slug":
				a.Slug = val
			case "description":
				a.Description = val
			case "keywords":
				a.Keywords = val
			case "theme":
				a.Theme = val
			case "created":
				a.Created = val
			case "updated":
				a.Updated = val
			}
		}
	}

	if a.Theme == "" {
		a.Theme, bodyMarkdown = peelThemeLine(bodyMarkdown)
	}

	var buf bytes.Buffer
	if err := goldmark.Convert([]byte(bodyMarkdown), &buf); err != nil {
		return Article{}, fmt.Errorf("rendering markdown: %w", err)
	}
	a.Body = buf.String()
	a.Excerpt = truncateRunes(bodyMarkdown, 255)

	return a, nil
}

// peelThemeLine removes a leading "Theme: …" line from the body and returns the theme value.
func peelThemeLine(body string) (theme, rest string) {
	body = strings.TrimLeft(body, "\n\r")
	first, after, found := strings.Cut(body, "\n")
	first = strings.TrimSpace(first)
	const prefix = "Theme:"
	if !strings.HasPrefix(first, prefix) && !strings.HasPrefix(strings.ToLower(first), "theme:") {
		return "", body
	}
	// Accept "Theme:" regardless of casing on the key
	idx := strings.Index(first, ":")
	theme = strings.TrimSpace(first[idx+1:])
	if !found {
		return theme, ""
	}
	return theme, strings.TrimSpace(after)
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
