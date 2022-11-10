package redis

import (
	"github.com/gomodule/redigo/redis"
)

type Handler struct {
	NewPool *redis.Pool
}

func New(newpool *redis.Pool) Handler {
	return Handler{newpool}
}
