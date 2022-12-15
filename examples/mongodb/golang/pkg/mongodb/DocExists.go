package mongodb

import (
	"context"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

func (h Handler) DocExists(dt string) bool {
	var res bson.M
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	err := h.col.FindOne(ctx, bson.D{{Key: "Title", Value: dt}}).Decode(&res)
	if err == mongo.ErrNoDocuments {
		// This error means the query did not match any documents.
		if len(res) == 0 {
			return false
		}
		return false

	} else {
		if len(res) != 0 {
			return true
		}

	}

	return false
}
