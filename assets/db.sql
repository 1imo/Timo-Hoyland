-- Project schema bootstrap (apply-db runs this after ensuring the database exists)

CREATE TABLE IF NOT EXISTS article (
    title TEXT NOT NULL PRIMARY KEY,
    keywords JSONB NOT NULL DEFAULT '[]'::jsonb,
    content TEXT NOT NULL,
    html TEXT NOT NULL DEFAULT '',
    views INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE article ADD COLUMN IF NOT EXISTS views INT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS article_updated_at_idx ON article (updated_at DESC);
