package mongodb

import (
	"context"
	"log"
	"net/http"
	"net/url"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

func (h Handler) GetOneDocByTitle(c *gin.Context) {
	encodedbook := c.Params.ByName("book")
	b, err := url.QueryUnescape(encodedbook)
	if err != nil {
		log.Printf("--- Decoding %s error: %s", encodedbook, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "Internal Error",
			"message": "Can not decode " + encodedbook,
			"error":   err.Error(),
		})
	}

	// var collection = models.MongoCollection{Database: "sampledb", Collection: "books"}
	// col := h.clt.Database(collection.Database).Collection(collection.Collection)
	var res bson.M
	if err := h.col.FindOne(context.TODO(), bson.D{{Key: "Title", Value: b}}).Decode(&res); err != nil {
		if err == mongo.ErrNoDocuments {
			// This error means the query did not match any documents.
			c.JSON(http.StatusNotFound, gin.H{
				"status":  "Not Found",
				"message": "Book titled " + b + " was not found.",
			})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "Internal Error",
				"message": "Can not get doc from mongoDB",
				"error":   err.Error(),
			})
		}
	} else {
		c.JSON(http.StatusOK, gin.H{
			"status":  "Ok",
			"message": "Got doc from mongoDB",
			"data": gin.H{
				"ID":     res["_id"],
				"Title":  res["Title"],
				"Author": res["Author"],
			},
		})
	}
}

func (h Handler) GetOneDocByID(c *gin.Context) {
	bookID := c.Params.ByName("uid")
	objID, _ := primitive.ObjectIDFromHex(bookID)

	var res bson.M
	if err := h.col.FindOne(context.TODO(), bson.M{"_id": objID}).Decode(&res); err != nil {
		if err == mongo.ErrNoDocuments {
			// This error means the query did not match any documents.
			c.JSON(http.StatusNotFound, gin.H{
				"status":  "Not Found",
				"message": "Book with ID " + bookID + " was not found.",
			})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "Internal Error",
				"message": "Can not get doc from mongoDB",
				"error":   err.Error(),
			})
		}
	} else {
		c.JSON(http.StatusOK, gin.H{
			"status":  "Ok",
			"message": "Got doc from mongoDB",
			"data": gin.H{
				"ID":     res["_id"],
				"Title":  res["Title"],
				"Author": res["Author"],
			},
		})
	}
}
