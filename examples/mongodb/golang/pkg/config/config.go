package config

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/bzhtux/servicebinding/bindings"
	"github.com/kelseyhightower/envconfig"
	"github.com/mitchellh/mapstructure"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/mongodb/golang/models"
	"gopkg.in/yaml.v2"
)

var (
	EnvConfigDir = strings.ToUpper(AppName) + "_CONFIG_DIR"
	AppVersion   = "0.0.2"
	AppPort      = 8080
)

const (
	DEFAULT_CONFIG_DIR    = "/config"
	ConfigFile            = "config.yml"
	AppName               = "gomongo"
	AppDesc               = "Golang MongoDB App for demo purpose"
	EnvServiceBindingRoot = "SERVICE_BINDING_ROOT"
)

type Conf models.Config

func (cfg *Conf) GetConfigDir() *Conf {
	cfg_dir, exists := os.LookupEnv(EnvConfigDir)
	if !exists {
		cfg.Dir.Root = DEFAULT_CONFIG_DIR
	} else {
		cfg.Dir.Root = cfg_dir
	}
	return cfg
}

func (cfg *Conf) LoadConfigFromFile() error {
	config := cfg.GetConfigDir()
	c, err := os.Open(filepath.Join(config.Dir.Root, ConfigFile))
	if err != nil {
		log.Printf("--- Error opening Config file: %s", err.Error())
		return err
	}
	defer c.Close()
	d := yaml.NewDecoder(c)
	if err := d.Decode(&cfg); err != nil {
		return err
	}
	return nil
}

func (cfg *Conf) LoadConfigFromBinding(t string) error {
	b, err := bindings.NewBinding(t)
	if err != nil {
		// log.Printf("--- Error getting bindings: %s", err.Error())
		return err
	}

	if err := mapstructure.Decode(b, &cfg.Database); err != nil {
		return err
	}

	return nil
}

func (cfg *Conf) NewConfig() {
	// 1st : Load Config from file
	cfg.LoadConfigFromFile()
	// 2nd : Load Config from env
	cfg.LoadConfigFromBinding("mongodb")
	// 3rd : Load Config from Bindings
	envconfig.Process("", cfg.Database)
}
