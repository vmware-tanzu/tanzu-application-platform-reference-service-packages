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
		Host       string
		Port       int
		Username   string
		Password   string
		Database   string
		Uri        string
		Collection struct {
			Database   string
			Collection string
		}
		Type	   struct
	}
}
