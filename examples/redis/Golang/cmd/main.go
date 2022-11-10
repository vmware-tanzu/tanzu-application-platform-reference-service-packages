package main

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/Golang/pkg/redis"
)

var (
	version = "v0.1.0"
)

func main() {
	fmt.Printf("\033[32mLauching sample_app-redis %s...\033[0m\n", version)
	redisPool := redis.NewPool()
	rh := redis.New(redisPool)
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
