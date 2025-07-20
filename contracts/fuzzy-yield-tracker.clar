;; fuzzy-yield-tracker
;; 
;; A transparent blockchain-based platform for tracking agricultural yields
;; Enables farmers, verifiers, and stakeholders to create immutable records
;; of agricultural activities, promoting trust and data integrity in farming.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-INVALID-FIELD (err u104))
(define-constant ERR-INVALID-PLANTING (err u105))
(define-constant ERR-FIELD-NOT-PLANTED (err u106))
(define-constant ERR-NOT-VERIFIER (err u107))

;; Data storage

;; Farmer registry - maps farmer's principal to their details
(define-map farmers
  { farmer: principal }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    registration-date: uint,
    active: bool
  }
)

;; Field registry - stores field information
(define-map fields
  { field-id: uint }
  {
    farmer: principal,
    location: (string-ascii 255),
    size-hectares: uint,
    soil-type: (string-ascii 50),
    registration-date: uint,
    active: bool
  }
)

;; Planting events - records when crops are planted
(define-map plantings
  { planting-id: uint }
  {
    field-id: uint,
    farmer: principal,
    crop-type: (string-ascii 100),
    planting-date: uint,
    inputs-used: (string-ascii 255), ;; Seeds, fertilizers, etc.
    additional-data: (string-ascii 255)
  }
)

;; Harvest records - documents yield results
(define-map harvests
  { harvest-id: uint }
  {
    planting-id: uint,
    field-id: uint,
    farmer: principal,
    yield-amount: uint, ;; in kilograms
    quality-metrics: (string-ascii 255),
    harvest-date: uint,
    additional-data: (string-ascii 255)
  }
)

;; Verifier registry - authorized third-party verifiers
(define-map verifiers
  { verifier: principal }
  {
    name: (string-ascii 100),
    verification-type: (string-ascii 100), ;; e.g., "organic", "quality", "sustainability"
    registration-date: uint,
    active: bool
  }
)

;; Verification attestations
(define-map verifications
  { verification-id: uint }
  {
    verifier: principal,
    target-type: (string-ascii 20), ;; "field", "planting", or "harvest"
    target-id: uint,
    verification-date: uint,
    status: (string-ascii 20), ;; "verified", "rejected", "pending"
    comments: (string-ascii 255)
  }
)

;; Access control for data visibility
(define-map data-access-control
  { data-type: (string-ascii 20), data-id: uint, accessor: principal }
  { 
    granted-by: principal,
    granted-at: uint,
    access-level: (string-ascii 20) ;; "full", "limited", "metadata-only"
  }
)

;; Counter variables for IDs
(define-data-var next-field-id uint u1)
(define-data-var next-planting-id uint u1)
(define-data-var next-harvest-id uint u1)
(define-data-var next-verification-id uint u1)

;; Private functions

;; Checks if a principal is a registered farmer
(define-private (is-registered-farmer (farmer principal))
  (default-to false (get active (map-get? farmers { farmer: farmer })))
)

;; Checks if the principal is the owner of a field
(define-private (is-field-owner (field-id uint) (farmer principal))
  (match (map-get? fields { field-id: field-id })
    field-data (is-eq (get farmer field-data) farmer)
    false
  )
)

;; Checks if a field has been planted
(define-private (is-field-planted (field-id uint))
  (is-some (map-get? plantings { planting-id: field-id }))
)

;; Checks if a principal is a registered verifier
(define-private (is-registered-verifier (verifier principal))
  (default-to false (get active (map-get? verifiers { verifier: verifier })))
)

;; Generate a new field ID and increment the counter
(define-private (generate-field-id)
  (let ((current-id (var-get next-field-id)))
    (var-set next-field-id (+ current-id u1))
    current-id
  )
)

;; Generate a new planting ID and increment the counter
(define-private (generate-planting-id)
  (let ((current-id (var-get next-planting-id)))
    (var-set next-planting-id (+ current-id u1))
    current-id
  )
)

;; Generate a new harvest ID and increment the counter
(define-private (generate-harvest-id)
  (let ((current-id (var-get next-harvest-id)))
    (var-set next-harvest-id (+ current-id u1))
    current-id
  )
)

;; Generate a new verification ID and increment the counter
(define-private (generate-verification-id)
  (let ((current-id (var-get next-verification-id)))
    (var-set next-verification-id (+ current-id u1))
    current-id
  )
)

;; Read-only functions

;; Get farmer information
(define-read-only (get-farmer-info (farmer principal))
  (map-get? farmers { farmer: farmer })
)

;; Get field information
(define-read-only (get-field-info (field-id uint))
  (map-get? fields { field-id: field-id })
)

;; Get planting information
(define-read-only (get-planting-info (planting-id uint))
  (map-get? plantings { planting-id: planting-id })
)

;; Get harvest information
(define-read-only (get-harvest-info (harvest-id uint))
  (map-get? harvests { harvest-id: harvest-id })
)

;; Get verifier information
(define-read-only (get-verifier-info (verifier principal))
  (map-get? verifiers { verifier: verifier })
)

;; Get verification information
(define-read-only (get-verification-info (verification-id uint))
  (map-get? verifications { verification-id: verification-id })
)

;; Check access rights for a given data type and ID
(define-read-only (check-data-access (data-type (string-ascii 20)) (data-id uint) (accessor principal))
  (map-get? data-access-control { data-type: data-type, data-id: data-id, accessor: accessor })
)

;; Public functions

;; Register as a farmer
(define-public (register-farmer (name (string-ascii 100)) (location (string-ascii 100)))
  (let ((farmer tx-sender))
    (if (is-registered-farmer farmer)
      ERR-ALREADY-EXISTS
      (begin
        (map-set farmers
          { farmer: farmer }
          {
            name: name,
            location: location,
            registration-date: block-height,
            active: true
          }
        )
        (ok true)
      )
    )
  )
)

;; Register a new field
(define-public (register-field 
    (location (string-ascii 255)) 
    (size-hectares uint) 
    (soil-type (string-ascii 50)))
  (let ((farmer tx-sender)
        (field-id (generate-field-id)))
    (if (not (is-registered-farmer farmer))
      ERR-NOT-AUTHORIZED
      (begin
        (map-set fields
          { field-id: field-id }
          {
            farmer: farmer,
            location: location,
            size-hectares: size-hectares,
            soil-type: soil-type,
            registration-date: block-height,
            active: true
          }
        )
        (ok field-id)
      )
    )
  )
)

;; Update field information
(define-public (update-field 
    (field-id uint) 
    (location (string-ascii 255)) 
    (size-hectares uint) 
    (soil-type (string-ascii 50)) 
    (active bool))
  (let ((farmer tx-sender))
    (if (not (is-field-owner field-id farmer))
      ERR-NOT-AUTHORIZED
      (match (map-get? fields { field-id: field-id })
        field-data (begin
          (map-set fields
            { field-id: field-id }
            {
              farmer: farmer,
              location: location,
              size-hectares: size-hectares,
              soil-type: soil-type,
              registration-date: (get registration-date field-data),
              active: active
            }
          )
          (ok true)
        )
        ERR-NOT-FOUND
      )
    )
  )
)

;; Record a planting event
(define-public (record-planting 
    (field-id uint) 
    (crop-type (string-ascii 100)) 
    (planting-date uint) 
    (inputs-used (string-ascii 255)) 
    (additional-data (string-ascii 255)))
  (let ((farmer tx-sender)
        (planting-id (generate-planting-id)))
    (if (not (is-field-owner field-id farmer))
      ERR-NOT-AUTHORIZED
      (match (map-get? fields { field-id: field-id })
        field-data (begin
          (map-set plantings
            { planting-id: planting-id }
            {
              field-id: field-id,
              farmer: farmer,
              crop-type: crop-type,
              planting-date: planting-date,
              inputs-used: inputs-used,
              additional-data: additional-data
            }
          )
          (ok planting-id)
        )
        ERR-INVALID-FIELD
      )
    )
  )
)

;; Record a harvest event
(define-public (record-harvest 
    (planting-id uint) 
    (yield-amount uint) 
    (quality-metrics (string-ascii 255)) 
    (harvest-date uint) 
    (additional-data (string-ascii 255)))
  (let ((farmer tx-sender)
        (harvest-id (generate-harvest-id)))
    (match (map-get? plantings { planting-id: planting-id })
      planting-data 
        (if (not (is-eq (get farmer planting-data) farmer))
          ERR-NOT-AUTHORIZED
          (begin
            (map-set harvests
              { harvest-id: harvest-id }
              {
                planting-id: planting-id,
                field-id: (get field-id planting-data),
                farmer: farmer,
                yield-amount: yield-amount,
                quality-metrics: quality-metrics,
                harvest-date: harvest-date,
                additional-data: additional-data
              }
            )
            (ok harvest-id)
          )
        )
      ERR-INVALID-PLANTING
    )
  )
)

;; Register as a verifier
(define-public (register-verifier (name (string-ascii 100)) (verification-type (string-ascii 100)))
  (let ((verifier tx-sender))
    (if (is-registered-verifier verifier)
      ERR-ALREADY-EXISTS
      (begin
        (map-set verifiers
          { verifier: verifier }
          {
            name: name,
            verification-type: verification-type,
            registration-date: block-height,
            active: true
          }
        )
        (ok true)
      )
    )
  )
)

;; Submit a verification attestation
(define-public (submit-verification 
    (target-type (string-ascii 20)) 
    (target-id uint) 
    (status (string-ascii 20)) 
    (comments (string-ascii 255)))
  (let ((verifier tx-sender)
        (verification-id (generate-verification-id)))
    (if (not (is-registered-verifier verifier))
      ERR-NOT-VERIFIER
      (begin
        (map-set verifications
          { verification-id: verification-id }
          {
            verifier: verifier,
            target-type: target-type,
            target-id: target-id,
            verification-date: block-height,
            status: status,
            comments: comments
          }
        )
        (ok verification-id)
      )
    )
  )
)

;; Grant data access to another principal
(define-public (grant-data-access 
    (data-type (string-ascii 20)) 
    (data-id uint) 
    (accessor principal) 
    (access-level (string-ascii 20)))
  (let ((granter tx-sender))
    ;; Check for field data type
    (if (is-eq data-type "field")
      (if (is-field-owner data-id granter)
        (begin
          (map-set data-access-control
            { data-type: data-type, data-id: data-id, accessor: accessor }
            { granted-by: granter, granted-at: block-height, access-level: access-level }
          )
          (ok true)
        )
        ERR-NOT-AUTHORIZED
      )
      ;; Check for planting data type
      (if (is-eq data-type "planting")
        (let ((planting-data (map-get? plantings { planting-id: data-id })))
          (if (is-some planting-data)
            (let ((pd (unwrap-panic planting-data)))
              (if (is-eq (get farmer pd) granter)
                (begin
                  (map-set data-access-control
                    { data-type: data-type, data-id: data-id, accessor: accessor }
                    { granted-by: granter, granted-at: block-height, access-level: access-level }
                  )
                  (ok true)
                )
                ERR-NOT-AUTHORIZED
              )
            )
            ERR-NOT-FOUND
          )
        )
        ;; Check for harvest data type
        (if (is-eq data-type "harvest")
          (let ((harvest-data (map-get? harvests { harvest-id: data-id })))
            (if (is-some harvest-data)
              (let ((hd (unwrap-panic harvest-data)))
                (if (is-eq (get farmer hd) granter)
                  (begin
                    (map-set data-access-control
                      { data-type: data-type, data-id: data-id, accessor: accessor }
                      { granted-by: granter, granted-at: block-height, access-level: access-level }
                    )
                    (ok true)
                  )
                  ERR-NOT-AUTHORIZED
                )
              )
              ERR-NOT-FOUND
            )
          )
          ;; Invalid data type
          ERR-INVALID-INPUT
        )
      )
    )
  )
)

;; Revoke previously granted data access
(define-public (revoke-data-access (data-type (string-ascii 20)) (data-id uint) (accessor principal))
  (let ((revoker tx-sender))
    (match (map-get? data-access-control { data-type: data-type, data-id: data-id, accessor: accessor })
      access-data
        (if (is-eq (get granted-by access-data) revoker)
          (begin
            (map-delete data-access-control { data-type: data-type, data-id: data-id, accessor: accessor })
            (ok true)
          )
          ERR-NOT-AUTHORIZED
        )
      ERR-NOT-FOUND
    )
  )
)