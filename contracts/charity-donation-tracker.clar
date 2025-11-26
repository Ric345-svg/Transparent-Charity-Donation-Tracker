(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_CAMPAIGN_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_MILESTONE_NOT_COMPLETED (err u103))
(define-constant ERR_CAMPAIGN_CLOSED (err u104))
(define-constant ERR_INVALID_MILESTONE (err u105))
(define-constant ERR_ALREADY_DONATED (err u106))
(define-constant ERR_INVALID_CATEGORY (err u107))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u108))
(define-constant ERR_UPDATE_NOT_FOUND (err u109))
(define-constant ERR_MATCHING_POOL_NOT_FOUND (err u110))
(define-constant ERR_MATCHING_POOL_EXHAUSTED (err u111))
(define-constant ERR_MATCHING_POOL_EXISTS (err u112))

(define-data-var campaign-counter uint u0)
(define-data-var update-counter uint u0)
(define-data-var matching-pool-counter uint u0)

(define-map categories
  { category-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    is-active: bool,
    created-at: uint
  }
)

(define-map campaign-categories
  { campaign-id: uint }
  { category-id: uint }
)

(define-data-var category-counter uint u0)

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

(define-map user-reputation
  { user: principal }
  {
    total-campaigns: uint,
    completed-campaigns: uint,
    successful-campaigns: uint,
    total-funds-raised: uint,
    reputation-score: uint,
    last-updated: uint
  }
)

(define-map reputation-history
  { user: principal, campaign-id: uint }
  {
    milestone-completion-rate: uint,
    funding-success-rate: uint,
    deadline-met: bool,
    reputation-impact: int
  }
)

(define-map campaign-updates
  { campaign-id: uint, update-id: uint }
  {
    title: (string-ascii 100),
    content: (string-ascii 500),
    update-type: (string-ascii 20),
    created-at: uint,
    is-important: bool
  }
)

(define-map campaign-update-count
  { campaign-id: uint }
  { count: uint }
)

(define-map user-subscriptions
  { campaign-id: uint, subscriber: principal }
  {
    subscribed-at: uint,
    notify-all: bool,
    notify-important: bool
  }
)

(define-map matching-pools
  { campaign-id: uint }
  {
    sponsor: principal,
    pool-amount: uint,
    remaining-amount: uint,
    match-ratio-numerator: uint,
    match-ratio-denominator: uint,
    max-match-per-donation: uint,
    total-matched: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map matched-donations
  { campaign-id: uint, donor: principal }
  {
    original-amount: uint,
    matched-amount: uint,
    total-impact: uint,
    matched-at: uint
  }
)

(define-map campaign-matching-stats
  { campaign-id: uint }
  {
    total-donors-matched: uint,
    total-matched-funds: uint,
    average-match-per-donor: uint
  }
)

(define-public (create-campaign 
  (beneficiary principal)
  (title (string-ascii 100))
  (description (string-ascii 500))
  (target-amount uint)
  (deadline uint)
  (total-milestones uint)
  (category-id uint))
  (let 
    (
      (campaign-id (+ (var-get campaign-counter) u1))
    )
    (asserts! (> total-milestones u0) ERR_INVALID_MILESTONE)
    (asserts! (> target-amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> deadline stacks-block-height) ERR_CAMPAIGN_CLOSED)
    (asserts! (<= total-milestones u10) ERR_INVALID_MILESTONE)
    (asserts! (is-some (map-get? categories { category-id: category-id })) ERR_INVALID_CATEGORY)
    
    (update-user-reputation-on-create tx-sender)
    
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
    
    (map-set campaign-categories
      { campaign-id: campaign-id }
      { category-id: category-id }
    )
    
    (map-set campaign-update-count
      { campaign-id: campaign-id }
      { count: u0 }
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
    
    (map-set user-subscriptions
      { campaign-id: campaign-id, subscriber: tx-sender }
      {
        subscribed-at: stacks-block-height,
        notify-all: true,
        notify-important: true
      }
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
    
    (update-reputation-on-milestone campaign-id (get owner campaign))
    
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
    
    (finalize-campaign-reputation campaign-id (get owner campaign))
    
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

(define-public (create-category 
  (name (string-ascii 50))
  (description (string-ascii 200)))
  (let 
    (
      (category-id (+ (var-get category-counter) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set categories
      { category-id: category-id }
      {
        name: name,
        description: description,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    
    (var-set category-counter category-id)
    (ok category-id)
  )
)

(define-public (deactivate-category (category-id uint))
  (let 
    (
      (category (unwrap! (map-get? categories { category-id: category-id }) ERR_INVALID_CATEGORY))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active category) ERR_INVALID_CATEGORY)
    
    (map-set categories
      { category-id: category-id }
      (merge category { is-active: false })
    )
    
    (ok true)
  )
)

(define-read-only (get-category (category-id uint))
  (map-get? categories { category-id: category-id })
)

(define-read-only (get-campaign-category (campaign-id uint))
  (map-get? campaign-categories { campaign-id: campaign-id })
)

(define-read-only (get-category-count)
  (var-get category-counter)
)

(define-private (update-user-reputation-on-create (user principal))
  (let 
    (
      (current-reputation (default-to 
        { 
          total-campaigns: u0, 
          completed-campaigns: u0, 
          successful-campaigns: u0, 
          total-funds-raised: u0, 
          reputation-score: u500, 
          last-updated: stacks-block-height 
        } 
        (map-get? user-reputation { user: user })
      ))
    )
    (map-set user-reputation
      { user: user }
      (merge current-reputation { 
        total-campaigns: (+ (get total-campaigns current-reputation) u1),
        last-updated: stacks-block-height
      })
    )
    true
  )
)

(define-private (update-reputation-on-milestone (campaign-id uint) (user principal))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign (let
      (
        (current-reputation (default-to 
          { 
            total-campaigns: u0, 
            completed-campaigns: u0, 
            successful-campaigns: u0, 
            total-funds-raised: u0, 
            reputation-score: u500, 
            last-updated: stacks-block-height 
          } 
          (map-get? user-reputation { user: user })
        ))
        (milestone-completion-rate (/ (* (get completed-milestones campaign) u100) (get total-milestones campaign)))
        (reputation-boost (if (> milestone-completion-rate u80) u10 u5))
      )
      (map-set user-reputation
        { user: user }
        (merge current-reputation { 
          reputation-score: (+ (get reputation-score current-reputation) reputation-boost),
          last-updated: stacks-block-height
        })
      )
      true
    )
    false
  )
)

(define-private (finalize-campaign-reputation (campaign-id uint) (user principal))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign (let
      (
        (current-reputation (default-to 
          { 
            total-campaigns: u0, 
            completed-campaigns: u0, 
            successful-campaigns: u0, 
            total-funds-raised: u0, 
            reputation-score: u500, 
            last-updated: stacks-block-height 
          } 
          (map-get? user-reputation { user: user })
        ))
        (is-successful (>= (get raised-amount campaign) (get target-amount campaign)))
        (milestone-completion-rate (/ (* (get completed-milestones campaign) u100) (get total-milestones campaign)))
        (funding-success-rate (/ (* (get raised-amount campaign) u100) (get target-amount campaign)))
        (deadline-met (< stacks-block-height (get deadline campaign)))
        (reputation-impact (+ 
          (if is-successful 50 -20)
          (if (> milestone-completion-rate u80) 30 -10)
          (if deadline-met 20 -15)
        ))
        (new-score (if (< reputation-impact 0)
          (if (> (get reputation-score current-reputation) (to-uint (- 0 reputation-impact)))
            (- (get reputation-score current-reputation) (to-uint (- 0 reputation-impact)))
            u0)
          (+ (get reputation-score current-reputation) (to-uint reputation-impact))))
      )
      (map-set user-reputation
        { user: user }
        (merge current-reputation { 
          completed-campaigns: (+ (get completed-campaigns current-reputation) u1),
          successful-campaigns: (+ (get successful-campaigns current-reputation) (if is-successful u1 u0)),
          total-funds-raised: (+ (get total-funds-raised current-reputation) (get raised-amount campaign)),
          reputation-score: new-score,
          last-updated: stacks-block-height
        })
      )
      
      (map-set reputation-history
        { user: user, campaign-id: campaign-id }
        {
          milestone-completion-rate: milestone-completion-rate,
          funding-success-rate: funding-success-rate,
          deadline-met: deadline-met,
          reputation-impact: reputation-impact
        }
      )
      
      true
    )
    false
  )
)

(define-read-only (get-user-reputation (user principal))
  (map-get? user-reputation { user: user })
)

(define-read-only (get-reputation-history (user principal) (campaign-id uint))
  (map-get? reputation-history { user: user, campaign-id: campaign-id })
)

(define-read-only (calculate-reputation-score (user principal))
  (match (map-get? user-reputation { user: user })
    reputation (some {
      base-score: (get reputation-score reputation),
      success-rate: (if (> (get total-campaigns reputation) u0) 
        (/ (* (get successful-campaigns reputation) u100) (get total-campaigns reputation)) 
        u0),
      completion-rate: (if (> (get total-campaigns reputation) u0) 
        (/ (* (get completed-campaigns reputation) u100) (get total-campaigns reputation)) 
        u0),
      total-impact: (get total-funds-raised reputation)
    })
    none
  )
)

(define-read-only (is-reputable-user (user principal) (min-score uint))
  (match (map-get? user-reputation { user: user })
    reputation (>= (get reputation-score reputation) min-score)
    false
  )
)

(define-public (post-campaign-update 
  (campaign-id uint)
  (title (string-ascii 100))
  (content (string-ascii 500))
  (update-type (string-ascii 20))
  (is-important bool))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (current-count (default-to { count: u0 } (map-get? campaign-update-count { campaign-id: campaign-id })))
      (update-id (+ (get count current-count) u1))
      (global-update-id (+ (var-get update-counter) u1))
    )
    (asserts! (is-eq tx-sender (get owner campaign)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    
    (map-set campaign-updates
      { campaign-id: campaign-id, update-id: update-id }
      {
        title: title,
        content: content,
        update-type: update-type,
        created-at: stacks-block-height,
        is-important: is-important
      }
    )
    
    (map-set campaign-update-count
      { campaign-id: campaign-id }
      { count: update-id }
    )
    
    (var-set update-counter global-update-id)
    
    (ok update-id)
  )
)

(define-public (subscribe-to-updates (campaign-id uint) (notify-all bool) (notify-important bool))
  (let 
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    )
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    
    (map-set user-subscriptions
      { campaign-id: campaign-id, subscriber: tx-sender }
      {
        subscribed-at: stacks-block-height,
        notify-all: notify-all,
        notify-important: notify-important
      }
    )
    
    (ok true)
  )
)

(define-public (unsubscribe-from-updates (campaign-id uint))
  (begin
    (map-delete user-subscriptions { campaign-id: campaign-id, subscriber: tx-sender })
    (ok true)
  )
)

(define-read-only (get-campaign-update (campaign-id uint) (update-id uint))
  (map-get? campaign-updates { campaign-id: campaign-id, update-id: update-id })
)

(define-read-only (get-campaign-update-count (campaign-id uint))
  (map-get? campaign-update-count { campaign-id: campaign-id })
)

(define-read-only (get-user-subscription (campaign-id uint) (subscriber principal))
  (map-get? user-subscriptions { campaign-id: campaign-id, subscriber: subscriber })
)

(define-read-only (is-subscribed-to-campaign (campaign-id uint) (subscriber principal))
  (is-some (map-get? user-subscriptions { campaign-id: campaign-id, subscriber: subscriber }))
)

(define-public (create-matching-pool
  (campaign-id uint)
  (pool-amount uint)
  (match-ratio-numerator uint)
  (match-ratio-denominator uint)
  (max-match-per-donation uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (existing-pool (map-get? matching-pools { campaign-id: campaign-id }))
    )
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    (asserts! (is-none existing-pool) ERR_MATCHING_POOL_EXISTS)
    (asserts! (> pool-amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> match-ratio-numerator u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> match-ratio-denominator u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> max-match-per-donation u0) ERR_INSUFFICIENT_FUNDS)
    
    (try! (stx-transfer? pool-amount tx-sender (as-contract tx-sender)))
    
    (map-set matching-pools
      { campaign-id: campaign-id }
      {
        sponsor: tx-sender,
        pool-amount: pool-amount,
        remaining-amount: pool-amount,
        match-ratio-numerator: match-ratio-numerator,
        match-ratio-denominator: match-ratio-denominator,
        max-match-per-donation: max-match-per-donation,
        total-matched: u0,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    
    (map-set campaign-matching-stats
      { campaign-id: campaign-id }
      {
        total-donors-matched: u0,
        total-matched-funds: u0,
        average-match-per-donor: u0
      }
    )
    
    (var-set matching-pool-counter (+ (var-get matching-pool-counter) u1))
    
    (ok true)
  )
)

(define-public (donate-with-matching (campaign-id uint) (amount uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (existing-donation (map-get? donations { campaign-id: campaign-id, donor: tx-sender }))
      (current-donors (default-to { donors: (list) } (map-get? campaign-donors { campaign-id: campaign-id })))
      (matching-pool (map-get? matching-pools { campaign-id: campaign-id }))
    )
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    (asserts! (< stacks-block-height (get deadline campaign)) ERR_CAMPAIGN_CLOSED)
    (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (is-none existing-donation) ERR_ALREADY_DONATED)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (let
      (
        (matching-result (match matching-pool
          pool (if (get is-active pool)
            (calculate-and-apply-match campaign-id amount pool)
            { matched-amount: u0, updated-pool: none })
          { matched-amount: u0, updated-pool: none }))
        (matched-amount (get matched-amount matching-result))
        (total-impact (+ amount matched-amount))
      )
      
      (map-set donations
        { campaign-id: campaign-id, donor: tx-sender }
        {
          amount: amount,
          donated-at: stacks-block-height
        }
      )
      
      (if (> matched-amount u0)
        (map-set matched-donations
          { campaign-id: campaign-id, donor: tx-sender }
          {
            original-amount: amount,
            matched-amount: matched-amount,
            total-impact: total-impact,
            matched-at: stacks-block-height
          }
        )
        true
      )
      
      (map-set campaign-donors
        { campaign-id: campaign-id }
        { donors: (unwrap! (as-max-len? (append (get donors current-donors) tx-sender) u100) ERR_INSUFFICIENT_FUNDS) }
      )
      
      (map-set campaigns
        { campaign-id: campaign-id }
        (merge campaign { raised-amount: (+ (get raised-amount campaign) total-impact) })
      )
      
      (map-set user-subscriptions
        { campaign-id: campaign-id, subscriber: tx-sender }
        {
          subscribed-at: stacks-block-height,
          notify-all: true,
          notify-important: true
        }
      )
      
      (ok { donated: amount, matched: matched-amount, total: total-impact })
    )
  )
)

(define-private (calculate-and-apply-match
  (campaign-id uint)
  (donation-amount uint)
  (pool {sponsor: principal, pool-amount: uint, remaining-amount: uint, match-ratio-numerator: uint, match-ratio-denominator: uint, max-match-per-donation: uint, total-matched: uint, is-active: bool, created-at: uint}))
  (let
    (
      (calculated-match (/ (* donation-amount (get match-ratio-numerator pool)) (get match-ratio-denominator pool)))
      (capped-match (if (> calculated-match (get max-match-per-donation pool))
        (get max-match-per-donation pool)
        calculated-match))
      (final-match (if (> capped-match (get remaining-amount pool))
        (get remaining-amount pool)
        capped-match))
      (new-remaining (- (get remaining-amount pool) final-match))
      (new-total-matched (+ (get total-matched pool) final-match))
      (stats (default-to { total-donors-matched: u0, total-matched-funds: u0, average-match-per-donor: u0 } (map-get? campaign-matching-stats { campaign-id: campaign-id })))
      (new-donor-count (+ (get total-donors-matched stats) u1))
      (new-total-matched-funds (+ (get total-matched-funds stats) final-match))
    )
    
    (map-set matching-pools
      { campaign-id: campaign-id }
      (merge pool {
        remaining-amount: new-remaining,
        total-matched: new-total-matched,
        is-active: (> new-remaining u0)
      })
    )
    
    (map-set campaign-matching-stats
      { campaign-id: campaign-id }
      {
        total-donors-matched: new-donor-count,
        total-matched-funds: new-total-matched-funds,
        average-match-per-donor: (/ new-total-matched-funds new-donor-count)
      }
    )
    
    { matched-amount: final-match, updated-pool: (some pool) }
  )
)

(define-public (top-up-matching-pool (campaign-id uint) (additional-amount uint))
  (let
    (
      (pool (unwrap! (map-get? matching-pools { campaign-id: campaign-id }) ERR_MATCHING_POOL_NOT_FOUND))
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get sponsor pool)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    (asserts! (> additional-amount u0) ERR_INSUFFICIENT_FUNDS)
    
    (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
    
    (map-set matching-pools
      { campaign-id: campaign-id }
      (merge pool {
        pool-amount: (+ (get pool-amount pool) additional-amount),
        remaining-amount: (+ (get remaining-amount pool) additional-amount),
        is-active: true
      })
    )
    
    (ok true)
  )
)

(define-public (deactivate-matching-pool (campaign-id uint))
  (let
    (
      (pool (unwrap! (map-get? matching-pools { campaign-id: campaign-id }) ERR_MATCHING_POOL_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get sponsor pool)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active pool) ERR_MATCHING_POOL_EXHAUSTED)
    
    (map-set matching-pools
      { campaign-id: campaign-id }
      (merge pool { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (reclaim-unused-matching-funds (campaign-id uint))
  (let
    (
      (pool (unwrap! (map-get? matching-pools { campaign-id: campaign-id }) ERR_MATCHING_POOL_NOT_FOUND))
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get sponsor pool)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-active campaign)) ERR_CAMPAIGN_CLOSED)
    (asserts! (> (get remaining-amount pool) u0) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? (get remaining-amount pool) tx-sender (get sponsor pool))))
    
    (map-set matching-pools
      { campaign-id: campaign-id }
      (merge pool {
        remaining-amount: u0,
        is-active: false
      })
    )
    
    (ok (get remaining-amount pool))
  )
)

(define-read-only (get-matching-pool (campaign-id uint))
  (map-get? matching-pools { campaign-id: campaign-id })
)

(define-read-only (get-matched-donation (campaign-id uint) (donor principal))
  (map-get? matched-donations { campaign-id: campaign-id, donor: donor })
)

(define-read-only (get-campaign-matching-stats (campaign-id uint))
  (map-get? campaign-matching-stats { campaign-id: campaign-id })
)

(define-read-only (calculate-potential-match (campaign-id uint) (donation-amount uint))
  (match (map-get? matching-pools { campaign-id: campaign-id })
    pool (if (get is-active pool)
      (let
        (
          (calculated-match (/ (* donation-amount (get match-ratio-numerator pool)) (get match-ratio-denominator pool)))
          (capped-match (if (> calculated-match (get max-match-per-donation pool))
            (get max-match-per-donation pool)
            calculated-match))
          (final-match (if (> capped-match (get remaining-amount pool))
            (get remaining-amount pool)
            capped-match))
        )
        (some {
          donation-amount: donation-amount,
          matched-amount: final-match,
          total-impact: (+ donation-amount final-match),
          match-ratio: (get match-ratio-numerator pool),
          remaining-pool: (get remaining-amount pool)
        })
      )
      none)
    none
  )
)

(define-read-only (get-matching-pool-status (campaign-id uint))
  (match (map-get? matching-pools { campaign-id: campaign-id })
    pool (some {
      has-pool: true,
      is-active: (get is-active pool),
      remaining-amount: (get remaining-amount pool),
      utilization-rate: (if (> (get pool-amount pool) u0)
        (/ (* (get total-matched pool) u100) (get pool-amount pool))
        u0),
      total-matched: (get total-matched pool),
      sponsor: (get sponsor pool)
    })
    (some {
      has-pool: false,
      is-active: false,
      remaining-amount: u0,
      utilization-rate: u0,
      total-matched: u0,
      sponsor: CONTRACT_OWNER
    })
  )
)

(define-read-only (get-matching-pool-count)
  (var-get matching-pool-counter)
)

;; Community Governance Features

(define-constant ERR_NOT_A_DONOR (err u113))
(define-constant ERR_ALREADY_VOTED (err u114))

(define-map shutdown-votes
  { campaign-id: uint, voter: principal }
  { voted: bool }
)

(define-map campaign-vote-count
  { campaign-id: uint }
  { count: uint }
)

(define-public (vote-to-shutdown (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (is-donor (is-some (map-get? donations { campaign-id: campaign-id, donor: tx-sender })))
      (has-voted (default-to false (get voted (map-get? shutdown-votes { campaign-id: campaign-id, voter: tx-sender }))))
      (current-votes (default-to u0 (get count (map-get? campaign-vote-count { campaign-id: campaign-id }))))
      (total-donors (len (get donors (unwrap! (map-get? campaign-donors { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))))
      (new-vote-count (+ current-votes u1))
    )
    (asserts! (get is-active campaign) ERR_CAMPAIGN_CLOSED)
    (asserts! is-donor ERR_NOT_A_DONOR)
    (asserts! (not has-voted) ERR_ALREADY_VOTED)

    (map-set shutdown-votes
      { campaign-id: campaign-id, voter: tx-sender }
      { voted: true }
    )

    (map-set campaign-vote-count
      { campaign-id: campaign-id }
      { count: new-vote-count }
    )

    ;; Close campaign if votes > 50% of donors
    (if (> (* new-vote-count u2) total-donors)
      (map-set campaigns
        { campaign-id: campaign-id }
        (merge campaign { is-active: false })
      )
      false
    )

    (ok true)
  )
)

(define-read-only (get-campaign-vote-stats (campaign-id uint))
  (let
    (
      (votes (default-to u0 (get count (map-get? campaign-vote-count { campaign-id: campaign-id }))))
      (donors-data (default-to { donors: (list) } (map-get? campaign-donors { campaign-id: campaign-id })))
      (total-donors (len (get donors donors-data)))
    )
    { votes: votes, total-donors: total-donors }
  )
)
