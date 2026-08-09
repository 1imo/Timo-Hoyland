package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// AIClient talks to an OpenAI-compatible chat completions API.
type AIClient struct {
	BaseURL    string
	APIKey     string
	Model      string
	HTTPClient *http.Client
}

func NewAIClient(baseURL, apiKey, model string) *AIClient {
	return &AIClient{
		BaseURL: strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		APIKey:  strings.TrimSpace(apiKey),
		Model:   strings.TrimSpace(model),
		HTTPClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func (c *AIClient) Enabled() bool {
	return c != nil && c.BaseURL != "" && c.APIKey != "" && c.Model != ""
}

type chatRequest struct {
	Model       string        `json:"model"`
	Temperature float64       `json:"temperature"`
	Messages    []chatMessage `json:"messages"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
}

func (c *AIClient) Chat(ctx context.Context, system, user string) (string, error) {
	if !c.Enabled() {
		return "", fmt.Errorf("AI client not configured")
	}
	endpoint := c.BaseURL
	if !strings.HasSuffix(endpoint, "/chat/completions") {
		endpoint = c.BaseURL + "/v1/chat/completions"
	}
	body, err := json.Marshal(chatRequest{
		Model:       c.Model,
		Temperature: 0.2,
		Messages: []chatMessage{
			{Role: "system", Content: system},
			{Role: "user", Content: user},
		},
	})
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("AI HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(raw)))
	}
	var out chatResponse
	if err := json.Unmarshal(raw, &out); err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", fmt.Errorf("AI returned no choices")
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), nil
}
