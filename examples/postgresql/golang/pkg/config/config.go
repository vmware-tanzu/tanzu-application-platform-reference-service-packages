package config

import (
	"log"
	"os"
	"path/filepath"

	"github.com/bzhtux/servicebinding/bindings"
	"github.com/kelseyhightower/envconfig"
	. "github.com/mitchellh/mapstructure"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/models"
	"gopkg.in/yaml.v2"
)

const (
	DEFAULT_CONFIG_DIR = "/config"
	pgConfigDir        = "PG_CONFIG_DIR"
	pgConfigFile       = "postgres.yaml"
)

type PGConfigDir struct {
	root string
}

type Config interface {
	NewConfig()
}

type PGConfig models.PGSpec

func GetConfigDir() *PGConfigDir {
	CONFIG_DIR, exists := os.LookupEnv(pgConfigDir)
	pgcd := &PGConfigDir{}
	if !exists {
		pgcd.root = DEFAULT_CONFIG_DIR
	} else {
		pgcd.root = CONFIG_DIR
	}
	return pgcd
}

func (pgc *PGConfig) LoadConfigFromFile() error {
	pgcd := GetConfigDir()
	cfg, err := os.Open(filepath.Join(pgcd.root, pgConfigFile))
	if err != nil {
		log.Printf("Error opening PostgreSQL config file: %s\n", err.Error())
		return err
	}
	defer cfg.Close()
	d := yaml.NewDecoder(cfg)
	if err := d.Decode(&pgc); err != nil {
		return err
	}
	return nil
}

func (cfg *PGConfig) LoadConfigFromEnv() {
	envconfig.Process("", cfg)
}

func (cfg *PGConfig) LoadConfigFromBindings(t string) error {

	b, err := bindings.NewBinding(t)
	if err != nil {
		log.Printf("Error while getting bindings: %s\n", err.Error())
		return err
	}

	if err := Decode(b, &cfg); err != nil {
		return err
	}

	return nil
}

func (cfg *PGConfig) NewConfig() *PGConfig {
	cfg.LoadConfigFromFile()
	cfg.LoadConfigFromBindings("postgresql")
	cfg.LoadConfigFromEnv()
	return cfg
}
