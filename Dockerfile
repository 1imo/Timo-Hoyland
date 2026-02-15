# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o server .

# Runtime stage
FROM alpine:3.19

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY --from=builder /app/server .
COPY --from=builder /app/articles ./articles
COPY --from=builder /app/templates ./templates

ENV PORT=8080
EXPOSE 8080

CMD ["./server"]
