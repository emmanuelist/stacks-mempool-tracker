
;; title: Mempool Real-Time Live Tracker
;; summary: Mempool Real-Time Live Tracker for Stacks Blockchain
;; description: This smart contract tracks mempool statistics, provides fee recommendations, and manages transaction data on the Stacks blockchain. It includes functionality for tracking transactions, updating transaction statuses, managing user watchlists, and updating fee statistics and mempool metrics. The contract also includes administrative functions for setting minimum fee thresholds and transferring contract ownership.

(use-trait ft-trait .sip-010-trait-ft-standard.sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-PARAMS (err u1001))
(define-constant ERR-NOT-FOUND (err u1002))
(define-constant ERR-ALREADY-EXISTS (err u1003))
(define-constant ERR-INVALID-FEE (err u1004))

;; Data structures
(define-map tracked-transactions 
    {tx-id: (string-ascii 64)}
    {
        fee-rate: uint,
        size: uint,
        priority: uint,
        timestamp: uint,
        confirmed: bool,
        category: (string-ascii 20),
        prediction: uint
    }
)

(define-map user-watchlists
    {user: principal}
    {
        tx-ids: (list 100 (string-ascii 64)),
        alert-threshold: uint,
        notifications-enabled: bool
    }
)

(define-map fee-stats
    {block-height: uint}
    {
        avg-fee: uint,
        min-fee: uint,
        max-fee: uint,
        recommended-low: uint,
        recommended-medium: uint,
        recommended-high: uint,
        total-tx-count: uint
    }
)

(define-map mempool-metrics
    {timestamp: uint}
    {
        size: uint,
        tx-count: uint,
        avg-confirmation-time: uint,
        congestion-level: uint
    }
)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var last-update uint u0)
(define-data-var total-tracked-tx uint u0)
(define-data-var min-fee-threshold uint u1) ;; in sats/byte

;; Authorization check
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; Utility functions
(define-private (validate-fee-rate (fee-rate uint))
    (if (>= fee-rate (var-get min-fee-threshold))
        true
        false
    )
)

(define-private (calculate-priority (fee-rate uint) (size uint))
    (let (
        (priority-score (* fee-rate size))
    )
        (cond
            ((>= priority-score u100000) u3) ;; high priority
            ((>= priority-score u50000) u2)  ;; medium priority
            (true u1)                        ;; low priority
        )
    )
)

(define-private (estimate-confirmation-time (fee-rate uint) (congestion uint))
    (let (
        (base-time u600) ;; 10 minutes in seconds
        (congestion-multiplier (+ u1 (/ congestion u100)))
    )
        (* base-time congestion-multiplier)
    )
)

;; Core functions
(define-public (track-transaction (tx-id (string-ascii 64)) (fee-rate uint) (size uint) (category (string-ascii 20)))
    (let (
        (priority (calculate-priority fee-rate size))
        (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
    )
        (asserts! (validate-fee-rate fee-rate) ERR-INVALID-FEE)
        (asserts! (not (default-to false (get confirmed (map-get? tracked-transactions {tx-id: tx-id})))) ERR-ALREADY-EXISTS)
        
        (map-set tracked-transactions
            {tx-id: tx-id}
            {
                fee-rate: fee-rate,
                size: size,
                priority: priority,
                timestamp: current-time,
                confirmed: false,
                category: category,
                prediction: (estimate-confirmation-time fee-rate (get-congestion-level))
            }
        )
        
        (var-set total-tracked-tx (+ (var-get total-tracked-tx) u1))
        (ok true)
    )
)

(define-public (update-transaction-status (tx-id (string-ascii 64)) (confirmed bool))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (match (map-get? tracked-transactions {tx-id: tx-id})
            tx-data (begin
                (map-set tracked-transactions
                    {tx-id: tx-id}
                    (merge tx-data {confirmed: confirmed})
                )
                (ok true)
            )
            ERR-NOT-FOUND
        )
    )
)

(define-public (add-to-watchlist (user principal) (tx-id (string-ascii 64)))
    (let (
        (current-watchlist (default-to {tx-ids: (list), alert-threshold: u0, notifications-enabled: false}
            (map-get? user-watchlists {user: user})))
    )
        (asserts! (< (len (get tx-ids current-watchlist)) u100) ERR-INVALID-PARAMS)
        (map-set user-watchlists
            {user: user}
            (merge current-watchlist 
                {tx-ids: (unwrap! (as-max-len? (append (get tx-ids current-watchlist) tx-id) u100) ERR-INVALID-PARAMS)}
            )
        )
        (ok true)
    )
)

(define-public (update-fee-statistics (block-height uint) (stats {avg-fee: uint, min-fee: uint, max-fee: uint, recommended-low: uint, recommended-medium: uint, recommended-high: uint, total-tx-count: uint}))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (map-set fee-stats
            {block-height: block-height}
            stats
        )
        (ok true)
    )
)

(define-read-only (get-transaction-details (tx-id (string-ascii 64)))
    (ok (map-get? tracked-transactions {tx-id: tx-id}))
)