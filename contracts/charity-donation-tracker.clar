(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_CAMPAIGN_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_MILESTONE_NOT_COMPLETED (err u103))
(define-constant ERR_CAMPAIGN_CLOSED (err u104))
(define-constant ERR_INVALID_MILESTONE (err u105))
(define-constant ERR_ALREADY_DONATED (err u106))

(define-data-var campaign-counter uint u0)

(define-map campaigns
  { campaign-id: uint }
  {
    owner: principal,
    beneficiary: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    target-amount: uint,
    raised-amount: uint,
    total-milestones: uint,
    completed-milestones: uint,
    is-active: bool,
    created-at: uint,
    deadline: uint
  }
)

(define-map campaign-milestones
  { campaign-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    amount: uint,
    is-completed: bool,
    completed-at: (optional uint)
  }
)

(define-map donations
  { campaign-id: uint, donor: principal }
  {
    amount: uint,
    donated-at: uint
  }
)

(define-map campaign-donors
  { campaign-id: uint }
  { donors: (list 100 principal) }
)

(define-public (create-campaign 
  (beneficiary principal)
  (title (string-ascii 100))
  (description (string-ascii 500))
  (target-amount uint)
  (deadline uint)
  (total-milestones uint))
  (let 
    (
      (campaign-id (+ (var-get campaign-counter) u1))
    )
    (asserts! (> total-milestones u0) ERR_INVALID_MILESTONE)
    (asserts! (> target-amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> deadline stacks-block-height) ERR_CAMPAIGN_CLOSED)
    (asserts! (<= total-milestones u10) ERR_INVALID_MILESTONE)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        owner: tx-sender,
        beneficiary: beneficiary,
        title: title,
        description: description,
        target-amount: target-amount,
        raised-amount: u0,
        total-milestones: total-milestones,
        completed-milestones: u0,
        is-active: true,
        created-at: stacks-block-height,
        deadline: deadline
      }
    )
    
    (var-set campaign-counter campaign-id)
    
    (map-set campaign-donors
      { campaign-id: campaign-id }
      { donors: (list) }
    )
    
    (ok campaign-id)
  )
)

(define-public (add-milestone
  (campaign-id uint)
  (milestone-id uint)
  (description (string-ascii 200))
  (amount uint))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner campaign)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (<= milestone-id (get total-milestones campaign)) ERR_INVALID_MILESTONE)
    
    (map-set campaign-milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      {
        description: description,
        amount: amount,
        is-completed: false,
        completed-at: none
      }
    )
    
    (ok true)
  )
)

(define-public (donate (campaign-id uint) (amount uint))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (existing-donation (map-get? donations { campaign-id: campaign-id, donor: tx-sender }))
      (current-donors (default-to { donors: (list) } (map-get? campaign-donors { campaign-id: campaign-id })))
    )
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    (asserts! (< stacks-block-height (get deadline campaign)) ERR_CAMPAIGN_CLOSED)
    (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (is-none existing-donation) ERR_ALREADY_DONATED)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set donations
      { campaign-id: campaign-id, donor: tx-sender }
      {
        amount: amount,
        donated-at: stacks-block-height
      }
    )
    
    (map-set campaign-donors
      { campaign-id: campaign-id }
      { donors: (unwrap! (as-max-len? (append (get donors current-donors) tx-sender) u100) ERR_INSUFFICIENT_FUNDS) }
    )
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { raised-amount: (+ (get raised-amount campaign) amount) })
    )
    
    (ok true)
  )
)

(define-public (complete-milestone (campaign-id uint) (milestone-id uint))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (milestone (unwrap! (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }) ERR_INVALID_MILESTONE))
    )
    (asserts! (is-eq tx-sender (get owner campaign)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-completed milestone)) ERR_MILESTONE_NOT_COMPLETED)
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    
    (map-set campaign-milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      (merge milestone { 
        is-completed: true,
        completed-at: (some stacks-block-height)
      })
    )
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { 
        completed-milestones: (+ (get completed-milestones campaign) u1)
      })
    )
    
    (ok true)
  )
)

(define-public (withdraw-milestone-funds (campaign-id uint) (milestone-id uint))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (milestone (unwrap! (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }) ERR_INVALID_MILESTONE))
    )
    (asserts! (is-eq tx-sender (get beneficiary campaign)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-completed milestone) ERR_MILESTONE_NOT_COMPLETED)
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    
    (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get beneficiary campaign))))
    
    (ok true)
  )
)

(define-public (close-campaign (campaign-id uint))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner campaign)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (refund-donation (campaign-id uint))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (donation (unwrap! (map-get? donations { campaign-id: campaign-id, donor: tx-sender }) ERR_INSUFFICIENT_FUNDS))
    )
    (asserts! (not (get is-active campaign)) ERR_CAMPAIGN_CLOSED)
    (asserts! (< (get completed-milestones campaign) (get total-milestones campaign)) ERR_MILESTONE_NOT_COMPLETED)
    
    (try! (as-contract (stx-transfer? (get amount donation) tx-sender tx-sender)))
    
    (map-delete donations { campaign-id: campaign-id, donor: tx-sender })
    
    (ok true)
  )
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-milestone (campaign-id uint) (milestone-id uint))
  (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id })
)

(define-read-only (get-donation (campaign-id uint) (donor principal))
  (map-get? donations { campaign-id: campaign-id, donor: donor })
)

(define-read-only (get-campaign-donors (campaign-id uint))
  (map-get? campaign-donors { campaign-id: campaign-id })
)

(define-read-only (get-campaign-count)
  (var-get campaign-counter)
)

(define-read-only (get-campaign-progress (campaign-id uint))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign (some {
      raised-percentage: (/ (* (get raised-amount campaign) u100) (get target-amount campaign)),
      milestone-percentage: (/ (* (get completed-milestones campaign) u100) (get total-milestones campaign))
    })
    none
  )
)

(define-read-only (is-milestone-exists (campaign-id uint) (milestone-id uint))
  (is-some (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }))
)

(define-read-only (get-total-campaign-funds (campaign-id uint))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign (get raised-amount campaign)
    u0
  )
)
