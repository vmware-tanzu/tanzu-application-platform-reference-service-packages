package postgresql

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/models"
)

func (h Handler) GetBookByID(c *gin.Context) {
	bookID := c.Params.ByName("uid")
	var book = models.Books{}
	r := h.DB.Where("ID = ?", bookID).First(&book)
	if r.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"status":  "Not Found",
			"message": "No book found with this ID",
			"data": gin.H{
				"ID": bookID,
			},
		})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"status":  "Ok",
			"message": "Book was successfuly found in DB",
			"data": gin.H{
				"ID":     bookID,
				"Title":  book.Title,
				"Author": book.Author,
			},
		})
	}
}
