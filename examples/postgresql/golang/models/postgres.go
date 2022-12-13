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
		Host     string
		Port     int
		Username string
		Password string
		Database string
		Type     string
		SSL      bool
	}
}
