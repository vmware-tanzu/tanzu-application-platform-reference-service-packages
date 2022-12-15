package models

import (
	"gorm.io/gorm"
)

type Books struct {
	*gorm.Model
	ID     uint   `gorm:"primaryKey"`
	Title  string `gorm:"not null" json:"title" binding:"required"`
	Author string `gorm:"not null" json:"author" binding:"required"`
}
