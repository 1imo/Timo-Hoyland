package routes

import (
	"fmt"
	htmltemplate "html/template"
	"log"
	"net"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
	texttemplate "text/template"

	"timohoyland.co.uk/controllers"
	"timohoyland.co.uk/use-cases/view"
	"timohoyland.co.uk/utils"
)

// Deps are injected collaborators for HTTP handlers.
type Deps struct {
	Site          *controllers.SiteController
	Views         *controllers.ViewsController
	Templates     *htmltemplate.Template
	TextTemplates *texttemplate.Template
	BaseURL       string
}

type pageData struct {
	Articles                    []view.Article
	Title                       string
	Description                 string
	Keywords                    string
	Body                        string
	Excerpt                     string
	Slug                        string
	Created                     string
	Updated                     string
	DisplayUpdated              string
	DetailPath                  string
	BaseURL                     string
	MatomoURL                   string
	MatomoSiteID                string
	GA4MeasurementID            string
	OpenReplayProjectKey        string
	OpenReplayIngestURL         string
	OpenReplayScriptURL         string
	OpenReplayDisableSecureMode bool
}

// NewTemplates loads HTML and plain-text templates from assets/templates.
func NewTemplates(assetsDir string) (*htmltemplate.Template, *texttemplate.Template, error) {
	funcs := htmltemplate.FuncMap{
		"raw": func(s string) htmltemplate.HTML { return htmltemplate.HTML(s) },
	}
	dir := filepath.Join(assetsDir, "templates")
	htmlFiles := []string{
		filepath.Join(dir, "index.html.tmpl"),
		filepath.Join(dir, "article.html.tmpl"),
	}
	tmpl, err := htmltemplate.New("root").Funcs(funcs).ParseFiles(htmlFiles...)
	if err != nil {
		return nil, nil, fmt.Errorf("parse templates: %w", err)
	}
	if _, err := tmpl.ParseGlob(filepath.Join(dir, "partials", "*.tmpl")); err != nil {
		return nil, nil, fmt.Errorf("parse partials: %w", err)
	}
	textTmpl, err := texttemplate.New("text").ParseFiles(
		filepath.Join(dir, "sitemap.xml.tmpl"),
		filepath.Join(dir, "robots.txt.tmpl"),
	)
	if err != nil {
		return nil, nil, fmt.Errorf("parse text templates: %w", err)
	}
	return tmpl, textTmpl, nil
}

// Handler returns the site mux.
func Handler(d Deps) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", d.handleIndex)
	mux.HandleFunc("/robots.txt", d.handleRobots)
	mux.HandleFunc("/sitemap.xml", d.handleSitemap)
	mux.HandleFunc("/article/", d.handleArticle)
	mux.HandleFunc("/legals/", d.handleLegal)
	mux.HandleFunc("/views/", d.handleViews)
	return mux
}

func (d Deps) handleViews(w http.ResponseWriter, r *http.Request) {
	if d.Views == nil {
		http.NotFound(w, r)
		return
	}
	d.Views.Increment(w, r)
}

func (d Deps) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := d.analytics(pageData{
		Articles: d.Site.Index(w, r),
		BaseURL:  d.baseURL(r),
	})
	if err := d.Templates.ExecuteTemplate(w, "index.html.tmpl", data); err != nil {
		log.Printf("index template: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func (d Deps) handleArticle(w http.ResponseWriter, r *http.Request) {
	slug := strings.TrimPrefix(r.URL.Path, "/article/")
	if slug == "" {
		http.Redirect(w, r, "/", http.StatusFound)
		return
	}
	art, ok := d.Site.Article(slug)
	if !ok {
		http.NotFound(w, r)
		return
	}
	d.renderArticle(w, r, art, "article")
}

func (d Deps) handleLegal(w http.ResponseWriter, r *http.Request) {
	slug := strings.TrimPrefix(r.URL.Path, "/legals/")
	if slug == "" {
		http.NotFound(w, r)
		return
	}
	art, ok := d.Site.Legal(slug)
	if !ok {
		http.NotFound(w, r)
		return
	}
	d.renderArticle(w, r, art, "legals")
}

func (d Deps) renderArticle(w http.ResponseWriter, r *http.Request, art view.Article, detailPath string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := d.analytics(pageData{
		Title:          art.Title,
		Description:    art.Description,
		Keywords:       art.Keywords,
		Body:           art.Body,
		Excerpt:        art.Excerpt,
		Slug:           art.Slug,
		Created:        art.Created,
		Updated:        art.Updated,
		DisplayUpdated: art.DisplayUpdated,
		DetailPath:     detailPath,
		BaseURL:        d.baseURL(r),
	})
	if err := d.Templates.ExecuteTemplate(w, "article.html.tmpl", data); err != nil {
		log.Printf("article template: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func (d Deps) handleRobots(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	if err := d.TextTemplates.ExecuteTemplate(w, "robots.txt.tmpl", struct{ BaseURL string }{BaseURL: d.baseURL(r)}); err != nil {
		log.Printf("robots template: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func (d Deps) handleSitemap(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	articles := d.Site.Index(w, r)
	if err := d.TextTemplates.ExecuteTemplate(w, "sitemap.xml.tmpl", struct {
		Articles []view.Article
		BaseURL  string
	}{Articles: articles, BaseURL: d.baseURL(r)}); err != nil {
		log.Printf("sitemap template: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func (d Deps) analytics(data pageData) pageData {
	if utils.C == nil {
		return data
	}
	data.MatomoURL = utils.C.MatomoURL
	data.MatomoSiteID = utils.C.MatomoSiteID
	data.GA4MeasurementID = utils.C.GA4MeasurementID
	data.OpenReplayProjectKey = utils.C.OpenReplayProjectKey
	data.OpenReplayIngestURL = utils.C.OpenReplayIngestURL
	data.OpenReplayScriptURL = utils.C.OpenReplayScriptURL
	data.OpenReplayDisableSecureMode = utils.C.OpenReplayDisableSecure
	return data
}

func (d Deps) baseURL(r *http.Request) string {
	if d.BaseURL != "" {
		return d.BaseURL
	}
	scheme := "https"
	if r.TLS == nil {
		if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
			scheme = proto
		} else {
			scheme = "http"
		}
	}
	host := r.Host
	if host == "" {
		host = "localhost"
	}
	if _, _, err := net.SplitHostPort(host); err == nil {
		// keep host:port
	}
	u := url.URL{Scheme: scheme, Host: host}
	return strings.TrimRight(u.String(), "/")
}
