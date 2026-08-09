package controllers

import (
	"errors"
	"net/http"
	"strings"

	"timohoyland.co.uk/use-cases/view"
)

// ViewsController handles article view-count increments.
type ViewsController struct {
	Views *view.Views
}

func NewViewsController(views *view.Views) *ViewsController {
	return &ViewsController{Views: views}
}

// Increment is POST /views/{slug}.
func (c *ViewsController) Increment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	slug := strings.TrimPrefix(r.URL.Path, "/views/")
	slug = strings.TrimSpace(slug)
	if slug == "" || strings.Contains(slug, "/") {
		http.NotFound(w, r)
		return
	}
	if err := c.Views.Increment(r.Context(), slug); err != nil {
		if errors.Is(err, view.ErrNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
