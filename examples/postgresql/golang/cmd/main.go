package main

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/models"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/pkg/config"
	pg "github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/pkg/postgresql"
)

func main() {
	cfg := new(config.Conf)
	cfg.NewConfig()
	fmt.Printf("*** Lauching App %s with version %s on port %d\n", cfg.App.Name, cfg.App.Version, cfg.App.Port)
	dbConn := pg.OpenDB(cfg)
	dbh := pg.New(dbConn, cfg)
	dbConn.AutoMigrate(&models.Books{})

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
	router.POST("/add", dbh.AddNewBook)
	router.GET("/get/:uid", dbh.GetBookByID)
	router.DELETE("/del/:uid", dbh.DeleteBook)
	router.Run(":" + strconv.Itoa(cfg.App.Port))
}
