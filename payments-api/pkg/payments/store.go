package payments

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/lib/pq"
)

var ErrConcurrency = errors.New("concurrency conflict")

const (
	ErrCodeUniqueViolation = "23505"
)

type EventStore struct {
	db *sql.DB
}

func NewEventStore(db *sql.DB) *EventStore {
	return &EventStore{db: db}
}

// Save atomically commits events.
// Ideally, for Double Entry, we want to save events for MULTIPLE aggregates in one transaction.
// This function accepts a map of AggregateID -> Events to save together.
func (es *EventStore) Save(eventsByAggregate map[string][]Event, expectedVersions map[string]int) error {
	tx, err := es.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	query := `
		INSERT INTO event_store (aggregate_id, aggregate_type, event_type, version, payload, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	for aggID, events := range eventsByAggregate {
		currentVersion := expectedVersions[aggID]

		for _, event := range events {
			currentVersion++ // Increment for the next event

			// Serialize Payload
			payloadBytes, err := json.Marshal(event)
			if err != nil {
				return err
			}

			// Execute Insert
			_, err = tx.Exec(query,
				aggID,
				AggregateTypeAccount,
				event.Type(),
				currentVersion,
				payloadBytes,
				time.Now(),
			)

			if err != nil {
				// Check for Unique Violation (Postgres Error Code 23505)
				if pqErr, ok := err.(*pq.Error); ok && pqErr.Code == ErrCodeUniqueViolation {
					return fmt.Errorf("%w: aggregate %s version %d already exists", ErrConcurrency, aggID, currentVersion)
				}
				return err
			}
		}
	}
	return tx.Commit()
}

func (es *EventStore) Load(aggregateID string, fromVersion int) ([]Event, int, error) {
	query := `
		SELECT event_type, payload, version
		FROM event_store
		WHERE aggregate_id = $1 AND version > $2
		ORDER BY version ASC
	`
	rows, err := es.db.Query(query, aggregateID, fromVersion)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var events []Event
	maxVersion := fromVersion

	for rows.Next() {
		var eType string
		var payload []byte
		var ver int

		if err := rows.Scan(&eType, &payload, &ver); err != nil {
			return nil, 0, err
		}

		// Deserialize based on Type
		ev, err := DeserializeEventPaylod(eType, payload)
		if err != nil {
			return nil, 0, err
		}

		events = append(events, ev)
		if ver > maxVersion {
			maxVersion = ver
		}
	}
	return events, maxVersion, nil
}

type SnapshotStore struct {
	db *sql.DB
}

func NewSnapshotStore(db *sql.DB) *SnapshotStore {
	return &SnapshotStore{db: db}
}

func (ss *SnapshotStore) Save(snap Snapshot) error {
	query := `
		INSERT INTO snapshots (aggregate_id, version, state, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (aggregate_id)
		DO UPDATE SET version = EXCLUDED.version, state = EXCLUDED.state, created_at = NOW();
	`
	_, err := ss.db.Exec(query, snap.AggregateID, snap.Version, snap.State)
	return err
}

func (ss *SnapshotStore) Load(aggregateID string) (*Snapshot, error) {
	query := `SELECT version, state FROM snapshots WHERE aggregate_id = $1`
	row := ss.db.QueryRow(query, aggregateID)

	var ver int
	var state []byte
	if err := row.Scan(&ver, &state); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No snapshot exists
		}
		return nil, err
	}

	return &Snapshot{
		AggregateID: aggregateID,
		Version:     ver,
		State:       state,
	}, nil
}
