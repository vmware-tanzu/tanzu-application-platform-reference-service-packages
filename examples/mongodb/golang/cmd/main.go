package main

import (
	"context"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/mongodb/golang/pkg/config"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/mongodb/golang/pkg/mongodb"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

func main() {
	cfg := new(config.Conf)
	cfg.NewConfig()
	log.Printf("\033[32m*** Lauching App %s with version %s on port %d***\033[0m\n", cfg.App.Name, cfg.App.Version, cfg.App.Port)
	clt, err := mongodb.NewClient(cfg)
	if err != nil {
		log.Printf("\033[31m---- Error Getting new MongoDB client \033[0m\n--- %s\n", err.Error())
	}
	if err := clt.Ping(context.TODO(), readpref.Primary()); err != nil {
		log.Printf("\033[31m--- Can not ping MongoDB instance \033[0m\n")
		log.Printf("--- %s", err.Error())
	} else {
		log.Printf("\033[32m+++ PING MongoDB instance is OK *\033[0m\n")
	}
	col, err := mongodb.NewCollection(clt, cfg)
	if err != nil {
		log.Printf("\033[31m--- Error Creating new MongoDB collection \033[0m\n")
		log.Printf("--- %s", err.Error())
	}
	mh := mongodb.New(clt, col, cfg)

	gin.SetMode(gin.ReleaseMode)
	// DebugMode should be used for dev only
	// gin.SetMode(gin.DebugMode)
	router := gin.Default()
	router.MaxMultipartMemory = 16 << 32 // 16 MiB

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "Up",
			"message": "Alive",
		})
	})
	router.GET("/ping", func(c *gin.Context) {
		if err := clt.Ping(context.TODO(), readpref.Primary()); err != nil {
			log.Printf("\033[31m--- Can not ping MongoDB innstance\033[0m\n--- %s\n", err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "Internal Error",
				"message": "MongoDB does not respond to PING command",
			})
		} else {
			log.Printf("\033[32m+++ PING MongoDB instance is OK\033[0m\n")
			c.JSON(http.StatusOK, gin.H{
				"status":  "Ok",
				"message": "MongoDB responded to PING :-)",
			})
		}
	})
	router.POST("/add", mh.AddNewDoc)
	router.GET("/get/byName/:book", mh.GetOneDocByTitle)
	router.GET("/get/byID/:uid", mh.GetOneDocByID)
	router.DELETE("/del/byName/:book", mh.DeleteOnDocByName)
	router.Run(":8080")
}
