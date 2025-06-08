;; Data Collection Contract
;; Collects and manages clinical trial data

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_DATA (err u301))
(define-constant ERR_DATA_NOT_FOUND (err u302))
(define-constant ERR_TRIAL_NOT_ACTIVE (err u303))

;; Data types
(define-constant DATA_TYPE_BASELINE u1)
(define-constant DATA_TYPE_FOLLOWUP u2)
(define-constant DATA_TYPE_ADVERSE_EVENT u3)
(define-constant DATA_TYPE_ENDPOINT u4)

;; Data structures
(define-map trial-data
  { trial-id: uint, patient-id: uint, data-id: uint }
  {
    data-type: uint,
    data-hash: (buff 32),
    timestamp: uint,
    recorded-by: principal,
    verified: bool,
    metadata: (string-ascii 200)
  }
)

(define-map data-verification
  { trial-id: uint, patient-id: uint, data-id: uint }
  {
    verifier: principal,
    verified-at: uint,
    verification-hash: (buff 32)
  }
)

(define-data-var next-data-id uint u1)

;; Record clinical data
(define-public (record-data
  (trial-id uint)
  (patient-id uint)
  (data-type uint)
  (data-hash (buff 32))
  (metadata (string-ascii 200))
)
  (let ((data-id (var-get next-data-id)))
    (asserts! (or (is-eq data-type DATA_TYPE_BASELINE)
                  (is-eq data-type DATA_TYPE_FOLLOWUP)
                  (is-eq data-type DATA_TYPE_ADVERSE_EVENT)
                  (is-eq data-type DATA_TYPE_ENDPOINT)) ERR_INVALID_DATA)
    (map-set trial-data
      { trial-id: trial-id, patient-id: patient-id, data-id: data-id }
      {
        data-type: data-type,
        data-hash: data-hash,
        timestamp: block-height,
        recorded-by: tx-sender,
        verified: false,
        metadata: metadata
      }
    )
    (var-set next-data-id (+ data-id u1))
    (ok data-id)
  )
)

;; Verify data entry
(define-public (verify-data
  (trial-id uint)
  (patient-id uint)
  (data-id uint)
  (verification-hash (buff 32))
)
  (match (map-get? trial-data { trial-id: trial-id, patient-id: patient-id, data-id: data-id })
    data-entry
    (begin
      (map-set trial-data
        { trial-id: trial-id, patient-id: patient-id, data-id: data-id }
        (merge data-entry { verified: true })
      )
      (map-set data-verification
        { trial-id: trial-id, patient-id: patient-id, data-id: data-id }
        {
          verifier: tx-sender,
          verified-at: block-height,
          verification-hash: verification-hash
        }
      )
      (ok true)
    )
    ERR_DATA_NOT_FOUND
  )
)

;; Get data entry
(define-read-only (get-data (trial-id uint) (patient-id uint) (data-id uint))
  (map-get? trial-data { trial-id: trial-id, patient-id: patient-id, data-id: data-id })
)

;; Get data verification
(define-read-only (get-verification (trial-id uint) (patient-id uint) (data-id uint))
  (map-get? data-verification { trial-id: trial-id, patient-id: patient-id, data-id: data-id })
)
