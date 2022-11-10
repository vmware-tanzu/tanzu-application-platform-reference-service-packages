package redis

import "log"

func (h Handler) KeyExists(k string) bool {
	client := h.NewPool.Get()
	defer client.Close()
	v, err := client.Do("GET", k)
	if err != nil {
		log.Printf("Error getting key %s", k)
		return true
	} else {
		if v == nil {
			return false
		} else {
			return true
		}
	}
}
