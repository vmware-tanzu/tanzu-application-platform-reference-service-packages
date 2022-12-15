package models

type Config struct {
	Dir struct {
		Root string
	}
	App struct {
		Name    string
		Desc    string
		Version string
		Port    int
	}
	Database struct {
		Host     string `yaml:"host" envconfig:"REDIS_HOST"`
		Port     int    `yaml:"port" envconnfig:"REDIS_PORT"`
		Username string `yaml:"username" envconfig:"REDIS_USERNAME"`
		Password string `yaml:"password" envconfig:"REDIS_PASSWORD"`
		DB       string `yaml:"database" envconfig:"REDIS_DB"`
		SSL      bool   `yaml:"sslenabled" envconfig:"REDIS_SSL"`
		Type     string `yaml:"type" envconfig:"REDIS_TYPE"`
	}
}
