package mongodb

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/mongodb/golang/models"
	"go.mongodb.org/mongo-driver/bson"
)

func (h Handler) AddNewDoc(c *gin.Context) {
	var book = models.Books{}
	if err := c.BindJSON(&book); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  "Bad request",
			"message": "Can not add a new doc :(",
			"error":   err.Error(),
		})
	} else {
		if h.DocExists(book.Title) {
			c.JSON(http.StatusConflict, gin.H{
				"status":  "Conflict",
				"message": "Book " + book.Title + " already exists.",
			})
		} else {
			var doc = bson.D{{Key: "Title", Value: book.Title}, {Key: "Author", Value: book.Author}}
			result, err := h.col.InsertOne(context.TODO(), doc)

			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{
					"status":  "Server Error",
					"message": "New book " + book.Title + " by " + book.Author + " was not added to " + h.CFG.Database.Collection.Collection + "' collection.",
					"error":   err.Error(),
				})
			} else {
				c.JSON(http.StatusCreated, gin.H{
					"status":  "OK",
					"message": "New book added to " + h.CFG.Database.Collection.Collection + "' collection",
					"data": gin.H{
						"Book title":  book.Title,
						"Book Author": book.Author,
						"ID":          result.InsertedID,
						"result":      result,
					},
				})
			}

		}
	}
}
