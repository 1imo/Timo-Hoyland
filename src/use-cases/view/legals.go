package view

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"unicode"

	"github.com/yuin/goldmark"
)

// LegalDoc is a markdown legal page before/after render.
type LegalDoc struct {
	Title       string
	Description string
	Body        string
	Slug        string
}

// Legals serves static legal markdown pages from assets/legals.
type Legals struct {
	Docs map[string]LegalDoc
	md   goldmark.Markdown
}

func LoadLegals(dir string) (*Legals, error) {
	md := newMarkdown()
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return &Legals{Docs: map[string]LegalDoc{}, md: md}, nil
		}
		return nil, err
	}

	out := map[string]LegalDoc{}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		slug := strings.TrimSuffix(e.Name(), ".md")
		raw, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			return nil, err
		}
		title := titleize(slug)
		description := ""
		bodyMD := string(raw)
		if parts := bytes.SplitN(raw, []byte("\n---\n"), 2); len(parts) == 2 {
			for _, line := range strings.Split(string(parts[0]), "\n") {
				line = strings.TrimSpace(line)
				switch {
				case strings.HasPrefix(line, "title:"):
					title = strings.Trim(strings.TrimSpace(strings.TrimPrefix(line, "title:")), `"`)
				case strings.HasPrefix(line, "description:"):
					description = strings.Trim(strings.TrimSpace(strings.TrimPrefix(line, "description:")), `"`)
				}
			}
			bodyMD = string(bytes.TrimSpace(parts[1]))
		}
		out[slug] = LegalDoc{
			Title:       title,
			Description: description,
			Body:        bodyMD,
			Slug:        slug,
		}
	}
	return &Legals{Docs: out, md: md}, nil
}

func (l *Legals) Render(slug, domain string) (LegalDoc, bool) {
	doc, ok := l.Docs[slug]
	if !ok {
		return LegalDoc{}, false
	}
	if strings.TrimSpace(domain) == "" {
		domain = "this website"
	}
	repl := strings.NewReplacer("{{DOMAIN}}", domain)
	bodyMD := repl.Replace(doc.Body)
	desc := repl.Replace(doc.Description)
	if desc == "" {
		desc = doc.Title
	}
	var buf bytes.Buffer
	if err := l.md.Convert([]byte(bodyMD), &buf); err != nil {
		return LegalDoc{}, false
	}
	return LegalDoc{
		Title:       doc.Title,
		Description: desc,
		Body:        buf.String(),
		Slug:        doc.Slug,
	}, true
}

func (l *Legals) AsArticle(doc LegalDoc) Article {
	return Article{
		Title:       doc.Title,
		Slug:        doc.Slug,
		Description: firstNonEmpty(doc.Description, doc.Title),
		Body:        doc.Body,
	}
}

func titleize(s string) string {
	parts := strings.Split(s, "-")
	for i, p := range parts {
		if p == "" {
			continue
		}
		r := []rune(p)
		r[0] = unicode.ToUpper(r[0])
		parts[i] = string(r)
	}
	return strings.Join(parts, " ")
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}
