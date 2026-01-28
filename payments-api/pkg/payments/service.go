package payments

import (
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"time"
)

const (
	MaxRetries = 5
)

type LedgerService struct {
	Es *EventStore
	Ss *SnapshotStore
}

func NewLedgerService(es *EventStore, ss *SnapshotStore) *LedgerService {
	return &LedgerService{es, ss}
}

func (s *LedgerService) CreateAccount(accID, owner string) error {
	ev := &AccountCreatedEvent{
		BaseEvent: BaseEvent{
			ID:          fmt.Sprintf("evt_%d", time.Now().UnixNano()),
			AggregateID: accID,
			Timestamp:   time.Now(),
		},
		Owner: owner,
	}
	err := s.Es.Save(map[string][]Event{accID: {ev}}, map[string]int{accID: 0})
	return err
}

// PostDoubleEntryTransaction performs an atomic transfer
func (s *LedgerService) PostDoubleEntryTransaction(txID, fromID, toID string, amount float64) error {
	// Retry loop for Optimistic Concurrency
	for i := 0; i < MaxRetries; i++ {
		err := s.attemptTransaction(txID, fromID, toID, amount)
		if err == nil {
			return nil
		}
		if errors.Is(err, ErrConcurrency) {
			// Exponential backoff
			sleep := time.Duration(rand.Intn(10*(i+1))) * time.Millisecond
			fmt.Printf("Concurrency conflict on TX %s. Retrying in %v...\n", txID, sleep)
			time.Sleep(sleep)
			continue
		}
		return err // Return actual business errors (e.g. insufficient funds)
	}
	return errors.New("failed to process transaction after max retries")
}

func (s *LedgerService) LoadAccount(id string) (*Account, error) {
	acc := NewAccount(id)

	// 1. Try Snapshot
	snap, err := s.Ss.Load(id)
	if err != nil {
		return nil, err
	}

	fromVer := 0
	if snap != nil {
		fromVer = snap.Version
	}

	// 2. Load Events
	events, maxVer, err := s.Es.Load(id, fromVer)
	if err != nil {
		return nil, err
	}

	// 3. Rehydrate
	if err := acc.Rehydrate(snap, events); err != nil {
		return nil, err
	}

	// Ensure version is accurate to what we loaded from DB
	if len(events) > 0 {
		acc.Version = maxVer
	} else if snap != nil {
		acc.Version = snap.Version
	}

	return acc, nil
}

func (s *LedgerService) attemptTransaction(txID, fromID, toID string, amount float64) error {
	// 1. Load Aggregates
	fromAcc, err := s.LoadAccount(fromID)
	if err != nil {
		return err
	}
	toAcc, err := s.LoadAccount(toID)
	if err != nil {
		return err
	}

	// 2. Validate Rules (Business Logic)
	if fromAcc.Balance < amount {
		return fmt.Errorf("insufficient funds in %s: has %.2f", fromAcc.ID, fromAcc.Balance)
	}

	// 3. Create Events
	ts := time.Now()
	ev1 := &TransactionPostedEvent{
		BaseEvent:     BaseEvent{ID: fmt.Sprintf("%s-dr", txID), AggregateID: fromID, Timestamp: ts},
		TransactionID: txID,
		Amount:        -amount, // Debit
		Reference:     "Transfer to " + toID,
	}
	ev2 := &TransactionPostedEvent{
		BaseEvent:     BaseEvent{ID: fmt.Sprintf("%s-cr", txID), AggregateID: toID, Timestamp: ts},
		TransactionID: txID,
		Amount:        amount, // Credit
		Reference:     "Transfer from " + fromID,
	}

	// 4. Prepare batch save
	eventsMap := map[string][]Event{
		fromID: {ev1},
		toID:   {ev2},
	}

	// We must pass the expected version for EACH aggregate involved
	versionsMap := map[string]int{
		fromID: fromAcc.Version,
		toID:   toAcc.Version,
	}

	// 5. Commit Atomically
	// If either account has changed version since we loaded, this fails.
	if err := s.Es.Save(eventsMap, versionsMap); err != nil {
		return err
	}

	// 6. Async Snapshot (Fire and forget, or handle errors)
	s.checkSnapshot(fromAcc, ev1)
	s.checkSnapshot(toAcc, ev2)

	return nil
}

func (s *LedgerService) checkSnapshot(acc *Account, ev Event) {
	acc.Apply(ev)
	acc.Version++
	if acc.Version%5 == 0 {
		snapBytes, _ := json.Marshal(acc)
		s.Ss.Save(Snapshot{AggregateID: acc.ID, Version: acc.Version, State: snapBytes})
		fmt.Printf("[Snapshot] Saved for %s at v%d\n", acc.ID, acc.Version)
	}
}
