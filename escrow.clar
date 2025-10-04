;; =============================================
;; MeMart Cargo Escrow Smart Contract
;; Stacks Hackathon Submission
;; Built by: SUREWAY INTEGRATED TECHNOLOGY SOLUTIONS LIMITED
;; CAMA 2020 Registered • RC: 8481374
;; =============================================

(define-constant CONTRACT_OWNER 'ST1PQHQKV0RJXZFYVDGX6M4U58RMMBN8ML1M9MSB9)
(define-constant PLATFORM_FEE 50) ;; 0.5% platform fee

(define-data-var escrow-counter uint u0)
(define-data-var total-volume uint u0)

(define-map escrows
    (uint)
    { 
        buyer: principal, 
        seller: principal, 
        amount: uint, 
        status: (string-ascii 20),
        created-at: uint,
        item-description: (string-ascii 100)
    }
)

(define-map merchant-stats
    (principal)
    { level: uint, total-transactions: uint, total-volume: uint }
)

;; Create a new escrow - DeFi Bounty Feature
(define-public (create-escrow (seller principal) (amount uint) (description (string-ascii 100)))
    (let (
        (escrow-id (var-get escrow-counter))
        (current-block (block-height))
    )
        (asserts (> amount u100000) (err u100)) ;; Minimum 1 STX
        (asserts (is-eq (get status (default-to { status: "none" } (map-get? escrows escrow-id)) "none") "none") (err u101))
        
        ;; Transfer STX to contract escrow
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Create escrow record
        (map-set escrows escrow-id 
            { 
                buyer: tx-sender, 
                seller: seller, 
                amount: amount, 
                status: "created", 
                created-at: current-block,
                item-description: description
            }
        )
        
        ;; Update merchant stats - Gaming Bounty Feature
        (update-merchant-stats tx-sender amount)
        
        ;; Update platform statistics
        (var-set total-volume (+ (var-get total-volume) amount))
        (var-set escrow-counter (+ escrow-id u1))
        
        (ok escrow-id)
    )
)

;; Complete escrow and release funds - DeFi Feature
(define-public (complete-escrow (escrow-id uint))
    (let (
        (escrow (unwrap-panic (map-get? escrows escrow-id)))
        (fee (/ (* (get amount escrow) PLATFORM_FEE) u10000))
        (amount-to-seller (- (get amount escrow) fee))
    )
        (asserts (is-eq tx-sender (get seller escrow)) (err u102)) ;; Only seller can complete
        (asserts (is-eq (get status escrow) "created") (err u103)) ;; Must be in created status
        
        ;; Transfer to seller (minus fee) and platform (fee)
        (try! (stx-transfer? amount-to-seller (as-contract tx-sender) (get seller escrow)))
        (try! (stx-transfer? fee (as-contract tx-sender) CONTRACT_OWNER))
        
        ;; Update status
        (map-set escrows escrow-id (merge escrow { status: "completed" }))
        
        ;; Update merchant stats for seller
        (update-merchant-stats (get seller escrow) (get amount escrow))
        
        (ok true)
    )
)

;; Cancel escrow - Only buyer can cancel before completion
(define-public (cancel-escrow (escrow-id uint))
    (let (
        (escrow (unwrap-panic (map-get? escrows escrow-id)))
    )
        (asserts (is-eq tx-sender (get buyer escrow)) (err u104)) ;; Only buyer can cancel
        (asserts (is-eq (get status escrow) "created") (err u103)) ;; Must be in created status
        
        ;; Refund buyer
        (try! (stx-transfer? (get amount escrow) (as-contract tx-sender) (get buyer escrow)))
        
        ;; Update status
        (map-set escrows escrow-id (merge escrow { status: "cancelled" }))
        
        (ok true)
    )
)

;; Update merchant statistics - Gaming Bounty Feature
(define-private (update-merchant-stats (merchant principal) (amount uint))
    (let (
        (current-stats (default-to { level: u1, total-transactions: u0, total-volume: u0 } (map-get? merchant-stats merchant)))
        (new-transactions (+ (get total-transactions current-stats) u1))
        (new-volume (+ (get total-volume current-stats) amount))
        (new-level (calculate-merchant-level new-volume))
    )
        (map-set merchant-stats merchant 
            { 
                level: new-level, 
                total-transactions: new-transactions, 
                total-volume: new-volume 
            }
        )
        (ok true)
    )
)

;; Calculate merchant level based on volume - Gaming Feature
(define-private (calculate-merchant-level (volume uint))
    (if (> volume u1000000000) u4 ;; 10,000+ STX = Enterprise
        (if (> volume u100000000) u3 ;; 1,000+ STX = Expert
            (if (> volume u10000000) u2 ;; 100+ STX = Professional
                u1 ;; Novice
            )
        )
    )
)

;; ========== READ-ONLY FUNCTIONS ==========

;; Get escrow details
(define-read-only (get-escrow (escrow-id uint))
    (ok (map-get? escrows escrow-id))
)

;; Get merchant statistics - Gaming Bounty Feature
(define-read-only (get-merchant-stats (merchant principal))
    (ok (map-get? merchant-stats merchant))
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    (ok {
        total-escrows: (var-get escrow-counter),
        total-volume: (var-get total-volume),
        platform-fee: PLATFORM_FEE
    })
)

;; Get merchant level name for UI display
(define-read-only (get-merchant-level-name (level uint))
    (ok (if (is-eq level u4) "Enterprise"
        (if (is-eq level u3) "Expert"
            (if (is-eq level u2) "Professional"
                "Novice"
            )
        )
    ))
)
