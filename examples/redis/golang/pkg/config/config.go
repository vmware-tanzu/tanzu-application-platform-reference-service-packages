package config

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/bzhtux/servicebinding/bindings"
	"github.com/jinzhu/copier"
	"github.com/kelseyhightower/envconfig"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/golang/models"
	"gopkg.in/yaml.v2"
)

var (
	EnvConfigDir = strings.ToUpper(AppName) + "_CONFIG_DIR"
	AppVersion   = "0.1.0"
	AppPort      = 8080
)

const (
	DEFAULT_CONFIG_DIR    = "/config"
	ConfigFile            = "config.yml"
	AppName               = "goredis"
	AppDesc               = "Golang Redis App for demo purpose"
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
		log.Printf("--- Error loading config file: %s\n", err.Error())
		return err
	}
	defer c.Close()

	d := yaml.NewDecoder(c)

	if err := d.Decode(&cfg); err != nil {
		log.Printf("--- Error decoding config file: %s\n", err.Error())
		return err
	}

	return nil
}

func (cfg *Conf) LoadConfigFromBindings(t string) error {
	b, err := bindings.NewBinding(t)
	if err != nil {
		log.Printf("--- Error while getting bindings: %s\n", err.Error())
		return err
	}

	copier.Copy(&cfg.Database, &b)
	return nil
}

func (cfg *Conf) NewConfig() {
	cfg.LoadConfigFromFile()
	cfg.LoadConfigFromBindings("redis")
	if err := envconfig.Process("", &cfg.Database); err != nil {
		log.Printf("Envconfig.process Error: %s", err.Error())
	}
}
