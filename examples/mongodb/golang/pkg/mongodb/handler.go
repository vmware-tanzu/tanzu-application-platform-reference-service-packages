package mongodb

import (
	"context"
	"log"
	"os"
	"strconv"
	"time"

	b64 "encoding/base64"

	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/mongodb/golang/pkg/config"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type Handler struct {
	clt *mongo.Client
	col *mongo.Collection
	CFG *config.Conf
}

func New(clt *mongo.Client, col *mongo.Collection, cfg *config.Conf) Handler {
	return Handler{clt, col, cfg}
}

func NewClient(cfg *config.Conf) (*mongo.Client, error) {
	var uri string
	var dbpass string

	_, exists := os.LookupEnv(config.EnvServiceBindingRoot)
	if exists {
		dbpass = cfg.Database.Password
	} else {
		dbpass_enc, _ := b64.StdEncoding.DecodeString(cfg.Database.Password)
		dbpass = string(dbpass_enc)
	}

	if cfg.Database.Uri != "" {
		uri = "mongodb://" + cfg.Database.Uri + "/?maxPoolSize=20&retryWrites=true&w=majority"
	} else {
		uri = "mongodb://" + cfg.Database.Username + ":" + dbpass + "@" + cfg.Database.Host + ":" + strconv.Itoa(int(cfg.Database.Port)) + "/?maxPoolSize=20&retryWrites=true&w=majority"
	}

	client, err := mongo.Connect(context.TODO(), options.Client().SetConnectTimeout(3*time.Second).SetServerSelectionTimeout(3*time.Second).ApplyURI(uri))
	if err != nil {
		log.Printf("--- Error Connecting to MongoDB instance: %s\n" + err.Error())
		return nil, err
	}
	return client, nil
}

func NewCollection(clt *mongo.Client, cfg *config.Conf) (*mongo.Collection, error) {
	return clt.Database(cfg.Database.Database).Collection(cfg.Database.Collection.Collection), nil
}
