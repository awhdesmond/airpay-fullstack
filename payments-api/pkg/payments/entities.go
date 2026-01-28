package payments

import (
	"encoding/json"
	"fmt"
	"time"
)

type AggregateType string

const (
	AggregateTypeAccount AggregateType = "ACCOUNT"
)

// EventType defines the type of event for serialization
type EventType string

const (
	EventAccountCreated    EventType = "ACCOUNT_CREATED"
	EventTransactionPosted EventType = "TXN_POSTED"
)

// Event is the interface all domain events must implement
type Event interface {
	Type() EventType
}

// BaseEvent contains metadata generic to all events
type BaseEvent struct {
	ID          string    `json:"id"`
	AggregateID string    `json:"aggregate_id"`
	Timestamp   time.Time `json:"timestamp"`
}

// AccountCreatedEvent happens when a new ledger account is opened
type AccountCreatedEvent struct {
	BaseEvent
	Owner string `json:"owner"`
}

func (e AccountCreatedEvent) Type() EventType {
	return EventAccountCreated
}

// TransactionPostedEvent records a change in balance.
// In Double Entry, a single "Transaction" command might generate multiple of these events (one per account),
// or a single event containing the full ledger entry.
// Here, we emit one event per affected account to keep Aggregate boundaries clean.
type TransactionPostedEvent struct {
	BaseEvent
	TransactionID string  `json:"transaction_id"`
	Amount        float64 `json:"amount"` // Positive for Debit (Asset inc), Negative for Credit (Liability inc) - or vice versa depending on convention
	Reference     string  `json:"reference"`
}

func (e TransactionPostedEvent) Type() EventType {
	return EventTransactionPosted
}

func DeserializeEventPaylod(eType string, payload []byte) (Event, error) {
	switch EventType(eType) {
	case EventAccountCreated:
		e := &AccountCreatedEvent{}
		_ = json.Unmarshal(payload, e)
		return e, nil
	case EventTransactionPosted:
		e := &TransactionPostedEvent{}
		_ = json.Unmarshal(payload, e)
		return e, nil
	}
	return nil, fmt.Errorf("invalid event type: %s", eType)
}

// Snapshot struct
type Snapshot struct {
	AggregateID string
	Version     int
	State       []byte
}

type Account struct {
	ID      string  `json:"id"`
	Balance float64 `json:"balance"`
	Version int     `json:"-"` // Don't serialize version into the JSON state blob, tracked separately
}

func NewAccount(id string) *Account {
	return &Account{ID: id, Balance: 0}
}

func (a *Account) Apply(event Event) {
	switch e := event.(type) {
	case *AccountCreatedEvent:
		a.ID = e.AggregateID
	case *TransactionPostedEvent:
		a.Balance += e.Amount
	}
}

func (a *Account) Rehydrate(snap *Snapshot, events []Event) error {
	if snap != nil {
		if err := json.Unmarshal(snap.State, a); err != nil {
			return err
		}
		a.Version = snap.Version
	}
	for _, e := range events {
		a.Apply(e)
		a.Version++
	}
	return nil
}
