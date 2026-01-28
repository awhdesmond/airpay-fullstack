package main

import (
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"syscall"

	"github.com/airpay/payments-api/pkg/api"
	"github.com/airpay/payments-api/pkg/common"
	"github.com/airpay/payments-api/pkg/payments"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

const (
	cfgFlagHost        = "host"
	cfgFlagPort        = "port"
	cfgFlagMetricsPort = "metrics-port"
	cfgFlagLogLevel    = "log-level"
	cfgFlagCORSOrigin  = "cors-origin"

	cfgFlagPostgresHost     = "postgres-host"
	cfgFlagPostgresPort     = "postgres-port"
	cfgFlagPostgresDatabase = "postgres-database"
	cfgFlagPostgresUsername = "postgres-username"
	cfgFlagPostgresPassword = "postgres-password"

	envVarPrefix = "PAYMENTS_SVC"

	defaultApiPort     = "8080"
	defaultMetricsPort = "9090"
	defaultLogLevel    = "info"
	defaultCORSOrigin  = "*"
)

type ServerConfig struct {
	common.PostgresSQLConfig `mapstructure:",squash"`

	Host        string `mapstructure:"host"`
	Port        string `mapstructure:"port"`
	MetricsPort string `mapstructure:"metrics-port"`
	CORSOrigin  string `mapstructure:"cors-origin"`
}

func (cfg ServerConfig) RedactedString() string {
	tmp := cfg
	tmp.PostgresSQLConfig.Password = "***"
	return fmt.Sprintf("%+v", tmp)
}

func (cfg ServerConfig) HTTPBindAddress() string {
	return fmt.Sprintf("%s:%s", cfg.Host, cfg.Port)
}

func (cfg ServerConfig) HTTPMetricsBindAddress() string {
	return fmt.Sprintf("%s:%s", cfg.Host, cfg.MetricsPort)
}

func main() {
	viper.SetDefault(cfgFlagHost, "")
	viper.SetDefault(cfgFlagPort, defaultApiPort)
	viper.SetDefault(cfgFlagMetricsPort, defaultMetricsPort)
	viper.SetDefault(cfgFlagLogLevel, defaultLogLevel)
	viper.SetDefault(cfgFlagCORSOrigin, defaultCORSOrigin)

	viper.SetDefault(cfgFlagPostgresHost, "")
	viper.SetDefault(cfgFlagPostgresPort, "")
	viper.SetDefault(cfgFlagPostgresDatabase, "")
	viper.SetDefault(cfgFlagPostgresUsername, "")
	viper.SetDefault(cfgFlagPostgresPassword, "")

	viper.SetEnvPrefix(envVarPrefix)
	viper.SetEnvKeyReplacer(strings.NewReplacer("-", "_"))
	viper.AutomaticEnv()

	logger, _ := common.InitZap(viper.GetString(cfgFlagLogLevel))
	defer func() {
		err := logger.Sync()
		if err != nil && !errors.Is(err, syscall.ENOTTY) {
			logger.Warn("logger sync failed", zap.Error(err))
		}
	}()
	defer zap.RedirectStdLog(logger)

	var srvCfg ServerConfig
	if err := viper.Unmarshal(&srvCfg); err != nil {
		logger.Panic("config unmarshal failed", zap.Error(err))
	}

	logger.Info("server configuration", zap.String("config", srvCfg.RedactedString()))

	apiSrv, err := makeAPIServer(srvCfg, logger)
	if err != nil {
		logger.Panic("error initialising api server", zap.Error(err))
	}

	go func() {
		logger.Info("starting api server",
			zap.String("host", srvCfg.Host),
			zap.String("port", srvCfg.Port),
			zap.String("commit", common.GitCommit),
			zap.String("version", common.Version),
		)
		if err := http.ListenAndServe(srvCfg.HTTPBindAddress(), apiSrv.Handler); err != nil {
			logger.Panic("error starting api server", zap.Error(err))
			os.Exit(1)
		}
	}()

	go func() {
		logger.Info("starting metrics server")
		http.Handle("/metrics", promhttp.Handler())
		if err := http.ListenAndServe(srvCfg.HTTPMetricsBindAddress(), nil); err != nil {
			logger.Panic("error starting metrics server", zap.Error(err))
			os.Exit(1)
		}
	}()

	// graceful shutdown
	stopCh := api.SetupSignalHandler()
	sd, _ := api.NewShutdown(logger)
	sd.Graceful(stopCh, apiSrv)

}

func makeAPIServer(cfg ServerConfig, logger *zap.Logger) (*http.Server, error) {
	pgSess, err := common.MakePostgresDBSession(cfg.PostgresSQLConfig)
	if err != nil {
		return nil, err
	}

	es := payments.NewEventStore(pgSess)
	ss := payments.NewSnapshotStore(pgSess)
	svc := payments.NewLedgerService(es, ss)
	handler := payments.NewLedgerHandler(svc)

	r := mux.NewRouter()
	securityMW := api.NewSecureHeadersMiddleware(cfg.CORSOrigin)
	wrwMW := api.NewWrappedReponseWriterMiddleware()
	loggingMW := api.NewMuxLoggingMiddleware(logger)
	metricsMW := api.NewMetricsMiddleware()

	r.Use(securityMW.Handler)
	r.Use(wrwMW.Handler)
	r.Use(loggingMW.Handler)
	r.Use(metricsMW.Handler)

	r.HandleFunc("/healthz", api.HealthzHandler)
	r.HandleFunc("/ready", api.HealthzHandler)
	api := r.PathPrefix("/api/v1").Subrouter()

	api.HandleFunc("/accounts", handler.CreateAccount).Methods("POST")
	api.HandleFunc("/transactions", handler.PostTransaction).Methods("POST")
	api.HandleFunc("/accounts/{id}", handler.GetBalance).Methods("GET")

	return &http.Server{Handler: r, Addr: cfg.HTTPBindAddress()}, nil
}
