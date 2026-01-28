package common

import (
	"database/sql"
	"fmt"
	"log"
)

type PostgresSQLConfig struct {
	Host     string `mapstructure:"postgres-host"`
	Port     string `mapstructure:"postgres-port"`
	Database string `mapstructure:"postgres-database"`
	Username string `mapstructure:"postgres-username"`
	Password string `mapstructure:"postgres-password"`
}

func MakePostgresDBSession(cfg PostgresSQLConfig) (*sql.DB, error) {
	connStr := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		cfg.Username, cfg.Password, cfg.Host, cfg.Port, cfg.Database,
	)
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	return db, nil
}
