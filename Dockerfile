# Build from repository root: docker build -t timohoyland .
# Runtime secrets: Vault Agent Injector → /vault/secrets/app (see manifests/service.yml).

FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY src/go.mod src/go.sum ./
RUN go mod download
COPY src/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /out/server .

FROM alpine:3.19
RUN apk add --no-cache ca-certificates \
  && addgroup -S -g 65532 nonroot \
  && adduser -S -u 65532 -G nonroot nonroot
WORKDIR /app

COPY --from=builder /out/server ./server
COPY assets ./assets
COPY settings.cfg.example ./settings.cfg
COPY project.cfg ./project.cfg
RUN chown -R nonroot:nonroot /app

USER 65532:65532
ENV PORT=8080
ENV ASSETS_DIR=/app/assets
ENV PROJECT_ROOT=/app
EXPOSE 8080
CMD ["./server"]
