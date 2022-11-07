package models

const (
	CONFIG_DIR = "/config"
)

type RedisSpec struct {
	Host       string `yaml:"host" envconfig:"REDIS_HOST"`
	Port       int    `yaml:"port" envconnfig:"REDIS_PORT"`
	Username   string `yaml:"username" envconfig:"REDIS_USERNAME"`
	Password   string `yaml:"password" envconfig:"REDIS_PASSWORD"`
	DB         string `yaml:"database" envconfig:"REDIS_DB"`
	SSLenabled bool   `yaml:"sslenabled" envconfig:"REDIS_SSL"`
}

type Messages struct {
	Key   string `json:"key" binding:"required"`
	Value string `json:"value" binding:"required"`
}
