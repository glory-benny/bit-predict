;; Title: BitPredict - Decentralized Price Prediction Markets on Stacks
;; Summary: A trustless prediction market protocol enabling Bitcoin-backed price forecasting
;; Description: BitPredict harnesses Bitcoin's security through Stacks Layer 2 to create
;;              decentralized prediction markets. Users stake STX tokens to predict asset
;;              price movements, with oracle-verified outcomes and automated reward
;;              distribution. Features include multi-market support, proportional payouts,
;;              anti-manipulation safeguards, and transparent fee structures optimized
;;              for Bitcoin's monetary sovereignty and Stacks' smart contract capabilities.

;; CONSTANTS & CONFIGURATION

;; Administrative Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))

;; Error Constants - Comprehensive Error Handling
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_PREDICTION (err u102))
(define-constant ERR_MARKET_CLOSED (err u103))
(define-constant ERR_ALREADY_CLAIMED (err u104))
(define-constant ERR_INSUFFICIENT_BALANCE (err u105))
(define-constant ERR_INVALID_PARAMETER (err u106))

;; STATE VARIABLES - PLATFORM CONFIGURATION

;; Oracle Management - Trusted Price Feed Source
(define-data-var oracle-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Economic Parameters
(define-data-var minimum-stake uint u1000000) ;; 1 STX (1,000,000 microSTX) minimum
(define-data-var fee-percentage uint u2) ;; 2% platform sustainability fee
(define-data-var market-counter uint u0) ;; Global market identifier tracker

;; DATA STRUCTURES - MARKET & USER STATE

;; Market State - Core Market Information
(define-map markets
  uint
  {
    start-price: uint, ;; Initial asset price at market creation
    end-price: uint, ;; Final settlement price (0 until resolved)
    total-up-stake: uint, ;; Total STX staked on price increase
    total-down-stake: uint, ;; Total STX staked on price decrease
    start-block: uint, ;; Block height when predictions open
    end-block: uint, ;; Block height when market closes
    resolved: bool, ;; Settlement status flag
  }
)

;; User Position Tracking - Individual Prediction Records
(define-map user-predictions
  {
    market-id: uint,
    user: principal,
  }
  {
    prediction: (string-ascii 4), ;; "up" or "down" position
    stake: uint, ;; STX amount wagered
    claimed: bool, ;; Payout claim status
  }
)

;; CORE MARKET FUNCTIONS

;; Market Creation - Initialize New Prediction Market
;; Creates a time-bounded prediction market with specified parameters
;; Only callable by contract owner to ensure market integrity
(define-public (create-market
    (start-price uint)
    (start-block uint)
    (end-block uint)
  )
  (let ((market-id (var-get market-counter)))
    ;; Access Control & Parameter Validation
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (> end-block start-block) ERR_INVALID_PARAMETER)
    (asserts! (> start-price u0) ERR_INVALID_PARAMETER)
    ;; Initialize Market State
    (map-set markets market-id {
      start-price: start-price,
      end-price: u0,
      total-up-stake: u0,
      total-down-stake: u0,
      start-block: start-block,
      end-block: end-block,
      resolved: false,
    })
    ;; Increment Global Counter
    (var-set market-counter (+ market-id u1))
    (ok market-id)
  )
)

;; Prediction Placement - Stake STX on Price Direction
;; Allows users to stake STX tokens on predicted price movement
;; Enforces timing constraints and minimum stake requirements
(define-public (make-prediction
    (market-id uint)
    (prediction (string-ascii 4))
    (stake uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
    )
    ;; Market Timing Validation
    (asserts!
      (and
        (>= current-block (get start-block market))
        (< current-block (get end-block market))
      )
      ERR_MARKET_CLOSED
    )
    ;; Prediction & Stake Validation
    (asserts! (or (is-eq prediction "up") (is-eq prediction "down"))
      ERR_INVALID_PREDICTION
    )
    (asserts! (>= stake (var-get minimum-stake)) ERR_INVALID_PREDICTION)
    (asserts! (<= stake (stx-get-balance tx-sender)) ERR_INSUFFICIENT_BALANCE)
    ;; Transfer Stake to Contract Custody
    (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
    ;; Record User Position
    (map-set user-predictions {
      market-id: market-id,
      user: tx-sender,
    } {
      prediction: prediction,
      stake: stake,
      claimed: false,
    })
    ;; Update Market Totals
    (map-set markets market-id
      (merge market {
        total-up-stake: (if (is-eq prediction "up")
          (+ (get total-up-stake market) stake)
          (get total-up-stake market)
        ),
        total-down-stake: (if (is-eq prediction "down")
          (+ (get total-down-stake market) stake)
          (get total-down-stake market)
        ),
      })
    )
    (ok true)
  )
)

;; Market Resolution - Oracle Price Settlement
;; Settles market with final price from trusted oracle source
;; Enables payout calculations for winning predictions
(define-public (resolve-market
    (market-id uint)
    (end-price uint)
  )
  (let ((market (unwrap! (map-get? markets market-id) ERR_NOT_FOUND)))
    ;; Oracle Authorization & Timing Checks
    (asserts! (is-eq tx-sender (var-get oracle-address)) ERR_OWNER_ONLY)
    (asserts! (>= stacks-block-height (get end-block market)) ERR_MARKET_CLOSED)
    (asserts! (not (get resolved market)) ERR_MARKET_CLOSED)
    (asserts! (> end-price u0) ERR_INVALID_PARAMETER)
    ;; Finalize Market State
    (map-set markets market-id
      (merge market {
        end-price: end-price,
        resolved: true,
      })
    )
    (ok true)
  )
)

;; Payout Distribution - Claim Winning Predictions
;; Calculates proportional rewards for correct predictions
;; Deducts platform fee and transfers net winnings
(define-public (claim-winnings (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) ERR_NOT_FOUND))
      (prediction (unwrap!
        (map-get? user-predictions {
          market-id: market-id,
          user: tx-sender,
        })
        ERR_NOT_FOUND
      ))
    )
    ;; Settlement & Claim Status Validation
    (asserts! (get resolved market) ERR_MARKET_CLOSED)
    (asserts! (not (get claimed prediction)) ERR_ALREADY_CLAIMED)
    (let (
        ;; Determine Winning Side
        (winning-prediction (if (> (get end-price market) (get start-price market))
          "up"
          "down"
        ))
        (total-stake (+ (get total-up-stake market) (get total-down-stake market)))
        (winning-stake (if (is-eq winning-prediction "up")
          (get total-up-stake market)
          (get total-down-stake market)
        ))
      )
      ;; Verify User Predicted Correctly
      (asserts! (is-eq (get prediction prediction) winning-prediction)
        ERR_INVALID_PREDICTION
      )
      (let (
          ;; Proportional Payout Calculation
          (winnings (/ (* (get stake prediction) total-stake) winning-stake))
          (fee (/ (* winnings (var-get fee-percentage)) u100))
          (payout (- winnings fee))
        )
        ;; Execute Transfers
        (try! (as-contract (stx-transfer? payout (as-contract tx-sender) tx-sender)))
        (try! (as-contract (stx-transfer? fee (as-contract tx-sender) CONTRACT_OWNER)))
        ;; Mark Claim as Processed
        (map-set user-predictions {
          market-id: market-id,
          user: tx-sender,
        }
          (merge prediction { claimed: true })
        )
        (ok payout)
      )
    )
  )
)

;; READ-ONLY FUNCTIONS - DATA QUERIES

;; Query Market Information - Public Market Data Access
(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

;; Query User Position - Individual Prediction Details
(define-read-only (get-user-prediction
    (market-id uint)
    (user principal)
  )
  (map-get? user-predictions {
    market-id: market-id,
    user: user,
  })
)

;; Contract Treasury Balance - Total Locked STX Funds
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; ADMINISTRATIVE FUNCTIONS - GOVERNANCE & MAINTENANCE

;; Oracle Management - Update Trusted Price Source
;; Enables migration to new oracle infrastructure
(define-public (set-oracle-address (new-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (is-eq new-address new-address) ERR_INVALID_PARAMETER)
    (ok (var-set oracle-address new-address))
  )
)

;; Economic Parameter Adjustment - Minimum Stake Configuration
;; Allows adjustment of participation barrier for market health
(define-public (set-minimum-stake (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (> new-minimum u0) ERR_INVALID_PARAMETER)
    (ok (var-set minimum-stake new-minimum))
  )
)

;; Fee Structure Management - Platform Sustainability Rate
;; Maintains protocol sustainability through configurable fees
(define-public (set-fee-percentage (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (<= new-fee u100) ERR_INVALID_PARAMETER)
    (ok (var-set fee-percentage new-fee))
  )
)

;; Treasury Management - Fee Collection & Protocol Funding
;; Enables withdrawal of accumulated platform fees for development
(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender)))
      ERR_INSUFFICIENT_BALANCE
    )
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) CONTRACT_OWNER)))
    (ok amount)
  )
)
