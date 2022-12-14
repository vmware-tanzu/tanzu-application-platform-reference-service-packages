package redis

import (
	"log"
	"strconv"

	"github.com/gomodule/redigo/redis"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/golang/pkg/config"
)

type Handler struct {
	NewPool *redis.Pool
	CFG     *config.Conf
}

func New(newpool *redis.Pool, cfg *config.Conf) Handler {
	return Handler{newpool, cfg}
}

func NewPool(cfg *config.Conf) (*redis.Pool, error) {

	redisDB, _ := strconv.Atoi(cfg.Database.DB)

	return &redis.Pool{
		MaxIdle:   80,
		MaxActive: 12000,
		Dial: func() (redis.Conn, error) {
			c, err := redis.Dial(
				"tcp",
				cfg.Database.Host+":"+strconv.Itoa(cfg.Database.Port),
				redis.DialDatabase(redisDB),
				redis.DialUsername(cfg.Database.Username),
				redis.DialPassword(cfg.Database.Password),
				redis.DialUseTLS(cfg.Database.SSL),
			)
			if err != nil {
				log.Println(err.Error())
			}
			return c, err
		},
	}, nil
}
