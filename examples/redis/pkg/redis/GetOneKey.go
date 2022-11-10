package redis

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gomodule/redigo/redis"
)

func (h Handler) GetOneKey(c *gin.Context) {
	key := c.Params.ByName("key")
	if h.KeyExists(key) {
		client := h.NewPool.Get()
		defer client.Close()
		v, err := redis.String(client.Do("GET", key))
		if err != nil {
			log.Println(err.Error())
		}
		c.JSON(http.StatusOK, gin.H{
			"status":  "Ok",
			"message": "Key was found",
			"data": gin.H{
				"key":   key,
				"value": v,
			},
		})
	} else {
		c.JSON(http.StatusNotFound, gin.H{
			"status":  "Not Found",
			"message": "Key was not found: " + key,
		})
	}
}
