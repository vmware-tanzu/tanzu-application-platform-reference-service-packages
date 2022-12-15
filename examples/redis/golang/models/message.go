package models

type Message struct {
	Key   string `json:"key" binding:"required"`
	Value string `json:"value" binding:"required"`
}
