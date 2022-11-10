package redis

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

func (h Handler) DelOneKey(c *gin.Context) {
	key := c.Params.ByName("key")

	if !h.KeyExists(key) {
		log.Printf("key %v does not exists", key)
		c.JSON(http.StatusNotFound, gin.H{
			"status":  "Not Found",
			"message": "Key was not found: " + key,
		})
	} else {
		client := h.NewPool.Get()
		defer client.Close()
		_, err := client.Do("DEL", key)
		if err != nil {
			log.Println(err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "Internal Server Error",
				"message": err.Error(),
			})
		} else {
			c.JSON(http.StatusOK, gin.H{
				"status":  "Ok",
				"message": "Key was successfuly deleted: " + key,
			})
		}
	}
}
