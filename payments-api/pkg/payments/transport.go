package payments

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/gorilla/mux"
)

type CreateAccountRequest struct {
	ID    string `json:"id"`
	Owner string `json:"owner"`
}

type TransactionRequest struct {
	TxID        string  `json:"tx_id"`
	FromAccount string  `json:"from_account"`
	ToAccount   string  `json:"to_account"`
	Amount      float64 `json:"amount"`
}

type BalanceResponse struct {
	AccountID string  `json:"account_id"`
	Balance   float64 `json:"balance"`
	UpdatedAt string  `json:"updated_at"`
}
type LedgerHandler struct {
	service *LedgerService // Write Side
}

func NewLedgerHandler(svc *LedgerService) *LedgerHandler {
	return &LedgerHandler{service: svc}
}

// POST /accounts
func (h *LedgerHandler) CreateAccount(w http.ResponseWriter, r *http.Request) {
	var req CreateAccountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	err := h.service.CreateAccount(req.ID, req.Owner)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create account: %v", err), http.StatusConflict)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "created", "id": req.ID})
}

// POST /transactions
func (h *LedgerHandler) PostTransaction(w http.ResponseWriter, r *http.Request) {
	var req TransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	if req.Amount <= 0 {
		http.Error(w, "Amount must be positive", http.StatusBadRequest)
		return
	}

	err := h.service.PostDoubleEntryTransaction(req.TxID, req.FromAccount, req.ToAccount, req.Amount)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "accepted", "tx_id": req.TxID})
}

// GET /accounts/{id}
// This is the Read Model query. It bypasses the Event Store and queries the View Table.
func (h *LedgerHandler) GetBalance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	accountID := vars["id"]

	acc, err := h.service.LoadAccount(accountID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	resp := BalanceResponse{
		AccountID: accountID,
		Balance:   acc.Balance,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}
