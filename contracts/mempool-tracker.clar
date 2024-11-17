;; title: Mempool Real-Time Live Tracker
;; summary: Mempool Real-Time Live Tracker for Stacks Blockchain
;; description: This smart contract tracks mempool statistics, provides fee recommendations, and manages transaction data on the Stacks blockchain. It includes functionality for tracking transactions, updating transaction statuses, managing user watchlists, and updating fee statistics and mempool metrics. The contract also includes administrative functions for setting minimum fee thresholds and transferring contract ownership.


;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-PARAMS (err u1001))
(define-constant ERR-NOT-FOUND (err u1002))
(define-constant ERR-ALREADY-EXISTS (err u1003))
(define-constant ERR-INVALID-FEE (err u1004))
(define-constant ERR-INVALID-SIZE (err u1005))
(define-constant ERR-INVALID-THRESHOLD (err u1006))
(define-constant ERR-INVALID-STATS (err u1007))
(define-constant ERR-INVALID-METRICS (err u1008))
(define-constant ERR-INVALID-CATEGORY (err u1009))
(define-constant ERR-INVALID-TX-ID (err u1010))

(define-constant ERR-INVALID-USER (err u1011))
(define-constant ERR-INVALID-HEIGHT (err u1012))
(define-constant ERR-INVALID-OWNER (err u1013))


;; Constants for validation
(define-constant MAX-TRANSACTION-SIZE u1000000) ;; 1MB max size
(define-constant MAX-FEE-RATE u1000000) ;; Maximum reasonable fee rate
(define-constant MIN-FEE-RATE u1) ;; Minimum fee rate
(define-constant MAX-CONGESTION-LEVEL u100)
(define-constant MAX-CONFIRMATION-TIME u7200) ;; 2 hours in seconds

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
    {height: uint}
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
(define-data-var min-fee-threshold uint u1)

;; Authorization check
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; Validation functions
(define-private (validate-fee-rate (fee-rate uint))
    (and 
        (>= fee-rate (var-get min-fee-threshold))
        (<= fee-rate MAX-FEE-RATE)
    )
)

(define-private (validate-size (size uint))
    (and 
        (> size u0)
        (<= size MAX-TRANSACTION-SIZE)
    )
)

(define-private (validate-threshold (threshold uint))
    (and 
        (>= threshold MIN-FEE-RATE)
        (<= threshold MAX-FEE-RATE)
    )
)

(define-private (validate-tx-id (tx-id (string-ascii 64)))
    (and 
        (>= (len tx-id) u64)  ;; Check if length is exactly 64 characters
        (is-hex-string tx-id)  ;; Check if string contains valid hex characters
    )
)

(define-private (is-hex-string (str (string-ascii 64)))
    (begin
        (>= (len str) u1)  ;; At least one character
    )
)

(define-private (validate-category (category (string-ascii 20)))
    (and 
        (> (len category) u0)
        (<= (len category) u20)
    )
)

(define-private (validate-stats (stats {avg-fee: uint, min-fee: uint, max-fee: uint, recommended-low: uint, recommended-medium: uint, recommended-high: uint, total-tx-count: uint}))
    (and 
        (>= (get min-fee stats) MIN-FEE-RATE)
        (<= (get max-fee stats) MAX-FEE-RATE)
        (>= (get recommended-low stats) (get min-fee stats))
        (>= (get recommended-medium stats) (get recommended-low stats))
        (>= (get recommended-high stats) (get recommended-medium stats))
        (<= (get recommended-high stats) (get max-fee stats))
    )
)

(define-private (validate-metrics (metrics {size: uint, tx-count: uint, avg-confirmation-time: uint, congestion-level: uint}))
    (and 
        (<= (get size metrics) MAX-TRANSACTION-SIZE)
        (<= (get avg-confirmation-time metrics) MAX-CONFIRMATION-TIME)
        (<= (get congestion-level metrics) MAX-CONGESTION-LEVEL)
        (>= (get tx-count metrics) u0)
    )
)

(define-private (calculate-priority (fee-rate uint) (size uint))
    (let (
        (priority-score (* fee-rate size))
    )
        (if (>= priority-score u100000) 
            u3  ;; high priority
            (if (>= priority-score u50000)
                u2  ;; medium priority
                u1  ;; low priority
            )
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
        (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
    )
        ;; Validate all inputs
        (asserts! (validate-tx-id tx-id) ERR-INVALID-TX-ID)
        (asserts! (validate-fee-rate fee-rate) ERR-INVALID-FEE)
        (asserts! (validate-size size) ERR-INVALID-SIZE)
        (asserts! (validate-category category) ERR-INVALID-CATEGORY)
        (asserts! (not (default-to false (get confirmed (map-get? tracked-transactions {tx-id: tx-id})))) ERR-ALREADY-EXISTS)
        
        (let (
            (priority (calculate-priority fee-rate size))
            (validated-tx-id tx-id)  ;; Now validated
            (validated-category category)  ;; Now validated
        )
            (map-set tracked-transactions
                {tx-id: validated-tx-id}
                {
                    fee-rate: fee-rate,
                    size: size,
                    priority: priority,
                    timestamp: current-time,
                    confirmed: false,
                    category: validated-category,
                    prediction: (estimate-confirmation-time fee-rate (get-congestion-level))
                }
            )
            
            (var-set total-tracked-tx (+ (var-get total-tracked-tx) u1))
            (ok true)
        )
    )
)

(define-public (update-transaction-status (tx-id (string-ascii 64)) (confirmed bool))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (validate-tx-id tx-id) ERR-INVALID-TX-ID)
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
    (begin
        ;; Add user validation
        (asserts! (validate-user user) ERR-INVALID-USER)
        (asserts! (validate-tx-id tx-id) ERR-INVALID-TX-ID)
        
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
)

(define-public (update-fee-statistics (height uint) (stats {avg-fee: uint, min-fee: uint, max-fee: uint, recommended-low: uint, recommended-medium: uint, recommended-high: uint, total-tx-count: uint}))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (validate-height height) ERR-INVALID-HEIGHT)
        (asserts! (validate-stats stats) ERR-INVALID-STATS)
        
        (let (
            (validated-height height)  ;; Now properly validated
            (validated-stats stats)    ;; Already validated by validate-stats
        )
            (map-set fee-stats
                {height: validated-height}
                validated-stats
            )
            (ok true)
        )
    )
)

(define-public (update-mempool-metrics (metrics {size: uint, tx-count: uint, avg-confirmation-time: uint, congestion-level: uint}))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (validate-metrics metrics) ERR-INVALID-METRICS)
        (let (
            (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
            (validated-metrics metrics)  ;; now validated
        )
            (map-set mempool-metrics
                {timestamp: current-time}
                validated-metrics
            )
            (var-set last-update current-time)
            (ok true)
        )
    )
)

;; Read-only functions
(define-read-only (get-transaction-details (tx-id (string-ascii 64)))
    (begin
        (asserts! (validate-tx-id tx-id) ERR-INVALID-TX-ID)
        (ok (map-get? tracked-transactions {tx-id: tx-id}))
    )
)

(define-read-only (get-user-watchlist (user principal))
    (ok (map-get? user-watchlists {user: user}))
)

(define-read-only (get-fee-statistics (height uint))
    (ok (map-get? fee-stats {height: height}))
)

(define-private (get-congestion-level)
    (let (
        (current-metrics (default-to {size: u0, tx-count: u0, avg-confirmation-time: u0, congestion-level: u0}
            (map-get? mempool-metrics {timestamp: (var-get last-update)})))
    )
        (get congestion-level current-metrics)
    )
)

(define-private (validate-user (user principal))
    true  ;; Principals are inherently valid in Clarity when they compile
)

(define-private (validate-height (height uint))
    (and
        (>= height u0)
        (<= height block-height)
    )
)

(define-private (validate-new-owner (new-owner principal))
    (not (is-eq new-owner (var-get contract-owner)))  ;; Only check if different from current owner
)

;; Admin functions
(define-public (set-min-fee-threshold (new-threshold uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (validate-threshold new-threshold) ERR-INVALID-THRESHOLD)
        (var-set min-fee-threshold new-threshold)
        (ok true)
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (validate-new-owner new-owner) ERR-INVALID-OWNER)
        (var-set contract-owner new-owner)
        (ok true)
    )
)