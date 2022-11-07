package models

import (
	"github.com/jinzhu/gorm"
)

type PGSpec struct {
	Host       string `yaml:"host" envconfig:"PG_HOST"`
	Port       int    `yaml:"port" envconnfig:"PG_PORT"`
	Username   string `yaml:"username" envconfig:"PG_USERNAME"`
	Password   string `yaml:"password" envconfig:"PG_PASSWORD"`
	Database   string `yaml:"database" envconfig:"PG_DB"`
	SSLenabled bool   `yaml:"sslenabled" envconfig:"PG_SSL"`
}

type Config interface {
	NewConfig()
}

type Books struct {
	*gorm.Model
	ID     uint   `gorm:"primaryKey"`
	Title  string `gorm:"not null" json:"title" binding:"required"`
	Author string `gorm:"not null" json:"author" binding:"required"`
}
