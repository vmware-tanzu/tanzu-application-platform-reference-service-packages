package postgresql

import (
	"fmt"
	"log"

	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/pkg/config"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func OpenDB() *gorm.DB {

	pgc := new(config.PGConfig)
	pgc.NewConfig()

	var dsn = fmt.Sprintf("host=%s port=%d user=%s dbname=%s sslmode=disable password=%s", pgc.Host, pgc.Port, pgc.Username, pgc.Database, pgc.Password)

	conn, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Printf("*** Error connecting to DB: %s\n", err)
	}

	return conn
}

func HealthCheck(dsn string) bool {
	_, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})

	if err != nil {
		return false
	} else {
		return true
	}
}

func AutoMigrate(db *gorm.DB, database interface{}) {

	db.AutoMigrate(database)

}
