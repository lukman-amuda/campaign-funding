;; Campaign Funding Smart Contract

;; Constants
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_CONTRACT_ALREADY_SETUP (err u101))
(define-constant ERR_RECORD_NOT_FOUND (err u102))
(define-constant ERR_CAMPAIGN_EXPIRED (err u103))
(define-constant ERR_TARGET_NOT_MET (err u104))
(define-constant ERR_BALANCE_TOO_LOW (err u105))
(define-constant ERR_INVALID_VALUE (err u106))
(define-constant ERR_INVALID_TIMEFRAME (err u107))

;; Data Variables
(define-data-var campaign-creator (optional principal) none)
(define-data-var target-amount uint u0)
(define-data-var collected-amount uint u0)
(define-data-var active-phase uint u0)
(define-data-var approval-count uint u0)
(define-data-var rejection-count uint u0)
(define-data-var total-backers uint u0)
(define-data-var campaign-deadline uint u0)
(define-data-var campaign-status (string-ascii 20) "not_started")

;; Maps
(define-map backer-investments principal uint)
(define-map project-phases uint {description: (string-utf8 256), amount: uint})

;; Private Functions
(define-private (is-campaign-creator)
  (is-eq (some tx-sender) (var-get campaign-creator))
)

(define-private (is-campaign-running)
  (and
    (is-eq (var-get campaign-status) "active")
    (<= block-height (var-get campaign-deadline))
  )
)

;; Public Functions
(define-public (setup-campaign (target uint) (timeframe uint))
  (begin
    (asserts! (is-none (var-get campaign-creator)) ERR_CONTRACT_ALREADY_SETUP)
    (asserts! (> target u0) ERR_INVALID_VALUE)
    (asserts! (and (> timeframe u0) (<= timeframe u52560)) ERR_INVALID_TIMEFRAME)
    (var-set campaign-creator (some tx-sender))
    (var-set target-amount target)
    (var-set campaign-deadline (+ block-height timeframe))
    (var-set campaign-status "active")
    (ok true)
  )
)

(define-public (make-investment (value uint))
  (let (
    (existing-investment (default-to u0 (map-get? backer-investments tx-sender)))
  )
    (asserts! (is-campaign-running) ERR_CAMPAIGN_EXPIRED)
    (asserts! (> value u0) ERR_INVALID_VALUE)
    (asserts! (<= (+ (var-get collected-amount) value) (var-get target-amount)) ERR_TARGET_NOT_MET)
    (try! (stx-transfer? value tx-sender (as-contract tx-sender)))
    (var-set collected-amount (+ (var-get collected-amount) value))
    (map-set backer-investments tx-sender (+ existing-investment value))
    (if (is-eq existing-investment u0)
      (var-set total-backers (+ (var-get total-backers) u1))
      true
    )
    (ok true)
  )
)

(define-public (cast-ballot (support bool))
  (let ((investment (default-to u0 (map-get? backer-investments tx-sender))))
    (asserts! (> investment u0) ERR_RECORD_NOT_FOUND)
    (asserts! (is-eq (var-get campaign-status) "voting") ERR_UNAUTHORIZED_ACCESS)
    (if support
      (var-set approval-count (+ (var-get approval-count) investment))
      (var-set rejection-count (+ (var-get rejection-count) investment))
    )
    (ok true)
  )
)

(define-public (initiate-ballot)
  (begin
    (asserts! (is-campaign-creator) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (is-eq (var-get campaign-status) "active") ERR_UNAUTHORIZED_ACCESS)
    (var-set campaign-status "voting")
    (var-set approval-count u0)
    (var-set rejection-count u0)
    (ok true)
  )
)

(define-public (conclude-ballot)
  (begin
    (asserts! (is-campaign-creator) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (is-eq (var-get campaign-status) "voting") ERR_UNAUTHORIZED_ACCESS)
    (let ((total-ballots (+ (var-get approval-count) (var-get rejection-count))))
      (asserts! (> total-ballots u0) ERR_RECORD_NOT_FOUND)
      (if (> (var-get approval-count) (var-get rejection-count))
        (begin
          (var-set active-phase (+ (var-get active-phase) u1))
          (var-set campaign-status "active")
          (ok true)
        )
        (begin
          (var-set campaign-status "active")
          (err u108)  ;; ERR_BALLOT_REJECTED
        )
      )
    )
  )
)

(define-public (create-phase (description (string-utf8 256)) (value uint))
  (begin
    (asserts! (is-campaign-creator) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (> value u0) ERR_INVALID_VALUE)
    (asserts! (<= (len description) u256) (err u109))  ;; ERR_INVALID_DESCRIPTION_LENGTH
    (map-set project-phases (var-get active-phase) {description: description, amount: value})
    (ok true)
  )
)

(define-public (extract-funds (value uint))
  (begin
    (asserts! (is-campaign-creator) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (> value u0) ERR_INVALID_VALUE)
    (asserts! (<= value (var-get collected-amount)) ERR_BALANCE_TOO_LOW)
    (as-contract (stx-transfer? value tx-sender (unwrap! (var-get campaign-creator) ERR_RECORD_NOT_FOUND)))
  )
)

(define-public (claim-refund)
  (let ((investment (default-to u0 (map-get? backer-investments tx-sender))))
    (asserts! (and
      (> block-height (var-get campaign-deadline))
      (< (var-get collected-amount) (var-get target-amount))
    ) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (> investment u0) ERR_RECORD_NOT_FOUND)
    (map-delete backer-investments tx-sender)
    (as-contract (stx-transfer? investment tx-sender tx-sender))
  )
)

;; Read-only Functions
(define-read-only (get-campaign-info)
  (ok {
    owner: (var-get campaign-creator),
    goal: (var-get target-amount),
    raised: (var-get collected-amount),
    end-height: (var-get campaign-deadline),
    state: (var-get campaign-status),
    current-milestone: (var-get active-phase)
  })
)

(define-read-only (get-investment (backer principal))
  (ok (default-to u0 (map-get? backer-investments backer)))
)

(define-read-only (get-phase (phase-id uint))
  (map-get? project-phases phase-id)
)