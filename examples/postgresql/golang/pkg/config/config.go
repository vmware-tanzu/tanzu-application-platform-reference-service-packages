package config

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/bzhtux/servicebinding/bindings"
	"github.com/kelseyhightower/envconfig"
	"github.com/mitchellh/mapstructure"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/postgresql/golang/models"
	"gopkg.in/yaml.v2"
)

var (
	EnvConfigDir = strings.ToUpper(AppName) + "_CONFIG_DIR"
	AppVersion   = "0.0.1"
	AppPort      = 8080
)

const (
	DEFAULT_CONFIG_DIR    = "/config"
	ConfigFile            = "config.yml"
	AppName               = "gopg"
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
		log.Printf("Error opening PostgreSQL config file: %s\n", err.Error())
		return err
	}
	defer c.Close()
	d := yaml.NewDecoder(c)
	if err := d.Decode(&cfg); err != nil {
		return err
	}
	return nil
}

func (cfg *Conf) LoadConfigFromBindings(t string) error {

	b, err := bindings.NewBinding(t)
	if err != nil {
		log.Printf("Error while getting bindings: %s\n", err.Error())
		return err
	}

	if err := mapstructure.Decode(b, &cfg); err != nil {
		return err
	}

	return nil
}

func (cfg *Conf) NewConfig() {
	// 1st : Load config from config file
	cfg.LoadConfigFromFile()
	// 2nd : Load config from bindings
	cfg.LoadConfigFromBindings("postgresql")
	// 3rd : Load config from env
	envconfig.Process("", cfg.Database)
}
