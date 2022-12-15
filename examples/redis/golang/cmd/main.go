package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/golang/pkg/config"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/golang/pkg/redis"
)

func main() {
	cfg := new(config.Conf)
	cfg.NewConfig()
	log.Printf("\033[32mLauching App %s with version %s on port %d\033[0m\n", cfg.App.Name, cfg.App.Version, cfg.App.Port)
	redisPool, err := redis.NewPool(cfg)
	if err != nil {
		log.Printf("--- Error getting new Redis Pool")
	}
	rh := redis.New(redisPool, cfg)
	gin.SetMode(gin.ReleaseMode)
	// Debug mode for dev phase only
	// gin.SetMode(gin.DebugMode)
	router := gin.Default()
	router.MaxMultipartMemory = 16 << 32 // 16 MiB

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "Up",
			"message": "Alive",
		})
	})
	router.POST("/add", rh.AddNewKey)
	router.GET("/get/:key", rh.GetOneKey)
	router.DELETE("/del/:key", rh.DelOneKey)
	router.Run(":8080")
}
