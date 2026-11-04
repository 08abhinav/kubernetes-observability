FROM golang:1.27-alpine AS build

WORKDIR /app
RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o application

FROM alpine:latest

WORKDIR /app
COPY --from=build /app/application .

EXPOSE 8080
CMD ["./application"]