package models

type Books struct {
	ID     int
	Title  string `binding:"required"`
	Author string `binding:"required"`
}
