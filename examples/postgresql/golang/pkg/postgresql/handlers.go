package postgresql

import (
	b64 "encoding/base64"
	"fmt"
	"log"
	"os"

	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/pkg/config"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type Handler struct {
	DB  *gorm.DB
	CFG *config.Conf
}

func New(db *gorm.DB, cfg *config.Conf) Handler {
	return Handler{db, cfg}
}

func OpenDB(cfg *config.Conf) *gorm.DB {
	var sslMode string

	if cfg.Database.SSL {
		sslMode = "enable"
	} else {
		sslMode = "disable"
	}

	var dbpass string
	dbpass = "nil"
	_, exists := os.LookupEnv(config.EnvServiceBindingRoot)
	if exists {
		dbpass = cfg.Database.Password
	} else {
		dbpass_enc, _ := b64.StdEncoding.DecodeString(cfg.Database.Password)
		dbpass = string(dbpass_enc)
	}

	var dsn = fmt.Sprintf("host=%s port=%d user=%s dbname=%s sslmode=%s password=%s", cfg.Database.Host, cfg.Database.Port, cfg.Database.Username, cfg.Database.Database, sslMode, dbpass)

	conn, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Printf("*** Error connectinng to DB: %s", err.Error())
	}

	return conn
}

func AutoMigrate(db *gorm.DB, database interface{}) {

	db.AutoMigrate(database)

}
