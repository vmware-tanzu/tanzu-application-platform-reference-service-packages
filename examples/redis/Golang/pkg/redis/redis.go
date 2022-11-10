package redis

import (
	"log"
	"strconv"

	"github.com/gomodule/redigo/redis"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/Golang/pkg/config"
)

func NewPool() *redis.Pool {

	rc := new(config.RedisConfig)
	rc.NewConfig()
	redisPort, _ := strconv.Atoi(rc.DB)

	return &redis.Pool{
		MaxIdle:   80,
		MaxActive: 12000,
		Dial: func() (redis.Conn, error) {
			c, err := redis.Dial(
				"tcp",
				rc.Host+":"+strconv.Itoa(rc.Port),
				redis.DialDatabase(redisPort),
				redis.DialUsername(rc.Username),
				redis.DialPassword(rc.Password),
				redis.DialUseTLS(rc.SSLenabled),
			)
			if err != nil {
				log.Println(err.Error())
			}
			return c, err
		},
	}
}
