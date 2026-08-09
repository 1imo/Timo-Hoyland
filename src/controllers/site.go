package controllers

import (
	"net/http"
	"strings"

	"timohoyland.co.uk/use-cases/view"
)

// SiteController serves public pages from the in-memory article cache + legals.
type SiteController struct {
	Articles *view.Articles
	Legals   *view.Legals
	Domain   string
}

func NewSiteController(articles *view.Articles, legals *view.Legals, domain string) *SiteController {
	return &SiteController{Articles: articles, Legals: legals, Domain: domain}
}

func (c *SiteController) Index(_ http.ResponseWriter, _ *http.Request) []view.Article {
	return c.Articles.List()
}

func (c *SiteController) Article(slug string) (view.Article, bool) {
	slug = strings.TrimSpace(slug)
	if slug == "" {
		return view.Article{}, false
	}
	return c.Articles.BySlug(slug)
}

func (c *SiteController) Legal(slug string) (view.Article, bool) {
	doc, ok := c.Legals.Render(slug, c.Domain)
	if !ok {
		return view.Article{}, false
	}
	return c.Legals.AsArticle(doc), true
}
