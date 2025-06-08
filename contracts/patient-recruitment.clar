;; Patient Recruitment Contract
;; Manages clinical trial patient recruitment

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_TRIAL_NOT_FOUND (err u201))
(define-constant ERR_PATIENT_NOT_FOUND (err u202))
(define-constant ERR_INVALID_CRITERIA (err u203))
(define-constant ERR_RECRUITMENT_CLOSED (err u204))

;; Recruitment status
(define-constant RECRUITMENT_OPEN u1)
(define-constant RECRUITMENT_CLOSED u2)
(define-constant RECRUITMENT_PAUSED u3)

;; Patient enrollment status
(define-constant PATIENT_PENDING u0)
(define-constant PATIENT_ENROLLED u1)
(define-constant PATIENT_REJECTED u2)
(define-constant PATIENT_WITHDRAWN u3)

;; Data structures
(define-map trials
  { trial-id: uint }
  {
    sponsor-id: uint,
    title: (string-ascii 200),
    target-enrollment: uint,
    current-enrollment: uint,
    recruitment-status: uint,
    inclusion-criteria: (string-ascii 500),
    exclusion-criteria: (string-ascii 500),
    created-at: uint
  }
)

(define-map patients
  { trial-id: uint, patient-id: uint }
  {
    patient-address: principal,
    enrollment-status: uint,
    enrolled-at: uint,
    consent-hash: (buff 32)
  }
)

(define-data-var next-trial-id uint u1)
(define-data-var next-patient-id uint u1)

;; Create a new trial
(define-public (create-trial
  (sponsor-id uint)
  (title (string-ascii 200))
  (target-enrollment uint)
  (inclusion-criteria (string-ascii 500))
  (exclusion-criteria (string-ascii 500))
)
  (let ((trial-id (var-get next-trial-id)))
    (map-set trials
      { trial-id: trial-id }
      {
        sponsor-id: sponsor-id,
        title: title,
        target-enrollment: target-enrollment,
        current-enrollment: u0,
        recruitment-status: RECRUITMENT_OPEN,
        inclusion-criteria: inclusion-criteria,
        exclusion-criteria: exclusion-criteria,
        created-at: block-height
      }
    )
    (var-set next-trial-id (+ trial-id u1))
    (ok trial-id)
  )
)

;; Enroll patient in trial
(define-public (enroll-patient (trial-id uint) (consent-hash (buff 32)))
  (match (map-get? trials { trial-id: trial-id })
    trial-data
    (begin
      (asserts! (is-eq (get recruitment-status trial-data) RECRUITMENT_OPEN) ERR_RECRUITMENT_CLOSED)
      (asserts! (< (get current-enrollment trial-data) (get target-enrollment trial-data)) ERR_RECRUITMENT_CLOSED)
      (let ((patient-id (var-get next-patient-id)))
        (map-set patients
          { trial-id: trial-id, patient-id: patient-id }
          {
            patient-address: tx-sender,
            enrollment-status: PATIENT_ENROLLED,
            enrolled-at: block-height,
            consent-hash: consent-hash
          }
        )
        (map-set trials
          { trial-id: trial-id }
          (merge trial-data { current-enrollment: (+ (get current-enrollment trial-data) u1) })
        )
        (var-set next-patient-id (+ patient-id u1))
        (ok patient-id)
      )
    )
    ERR_TRIAL_NOT_FOUND
  )
)

;; Get trial information
(define-read-only (get-trial (trial-id uint))
  (map-get? trials { trial-id: trial-id })
)

;; Get patient information
(define-read-only (get-patient (trial-id uint) (patient-id uint))
  (map-get? patients { trial-id: trial-id, patient-id: patient-id })
)
