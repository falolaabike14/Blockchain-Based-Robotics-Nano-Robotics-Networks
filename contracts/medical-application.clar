;; Medical Application Contract
;; Manages nano-robotics medical uses and patient data

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_PATIENT_NOT_FOUND (err u501))
(define-constant ERR_TREATMENT_NOT_FOUND (err u502))
(define-constant ERR_INVALID_DOSAGE (err u503))
(define-constant ERR_TREATMENT_COMPLETED (err u504))

;; Treatment types
(define-constant TREATMENT_DRUG_DELIVERY u1)
(define-constant TREATMENT_DIAGNOSTICS u2)
(define-constant TREATMENT_SURGERY u3)
(define-constant TREATMENT_MONITORING u4)
(define-constant TREATMENT_REPAIR u5)

;; Treatment status
(define-constant STATUS_PLANNED u1)
(define-constant STATUS_ACTIVE u2)
(define-constant STATUS_PAUSED u3)
(define-constant STATUS_COMPLETED u4)
(define-constant STATUS_CANCELLED u5)

;; Data structures
(define-map patients
  { patient-id: uint }
  {
    medical-id: (string-ascii 50),
    authorized-doctor: principal,
    age: uint,
    weight: uint,
    medical-conditions: (string-ascii 200),
    allergies: (string-ascii 200),
    consent-given: bool,
    registration-date: uint
  }
)

(define-map medical-treatments
  { treatment-id: uint }
  {
    patient-id: uint,
    doctor: principal,
    treatment-type: uint,
    description: (string-ascii 300),
    nano-robots-assigned: uint,
    target-area: (string-ascii 100),
    dosage: uint,
    duration: uint,
    status: uint,
    start-date: (optional uint),
    completion-date: (optional uint),
    side-effects: (optional (string-ascii 200))
  }
)

(define-map treatment-progress
  { treatment-id: uint }
  {
    progress-percentage: uint,
    vital-signs: (string-ascii 100),
    effectiveness: uint,
    last-update: uint,
    notes: (string-ascii 300)
  }
)

(define-map nano-medical-robots
  { robot-id: uint }
  {
    treatment-id: uint,
    robot-type: (string-ascii 50),
    payload: (string-ascii 100),
    target-coordinates: (string-ascii 50),
    deployment-date: uint,
    status: uint,
    battery-level: uint,
    mission-progress: uint
  }
)

(define-data-var next-patient-id uint u1)
(define-data-var next-treatment-id uint u1)

;; Register patient
(define-public (register-patient
  (medical-id (string-ascii 50))
  (age uint)
  (weight uint)
  (medical-conditions (string-ascii 200))
  (allergies (string-ascii 200))
)
  (let ((patient-id (var-get next-patient-id)))
    (map-set patients
      { patient-id: patient-id }
      {
        medical-id: medical-id,
        authorized-doctor: tx-sender,
        age: age,
        weight: weight,
        medical-conditions: medical-conditions,
        allergies: allergies,
        consent-given: true,
        registration-date: block-height
      }
    )

    (var-set next-patient-id (+ patient-id u1))
    (ok patient-id)
  )
)

;; Create medical treatment plan
(define-public (create-treatment
  (patient-id uint)
  (treatment-type uint)
  (description (string-ascii 300))
  (nano-robots-count uint)
  (target-area (string-ascii 100))
  (dosage uint)
  (duration uint)
)
  (let ((treatment-id (var-get next-treatment-id)))
    (match (map-get? patients { patient-id: patient-id })
      patient-data
      (begin
        (asserts! (is-eq tx-sender (get authorized-doctor patient-data)) ERR_UNAUTHORIZED)
        (asserts! (<= treatment-type TREATMENT_REPAIR) ERR_UNAUTHORIZED)
        (asserts! (> dosage u0) ERR_INVALID_DOSAGE)

        (map-set medical-treatments
          { treatment-id: treatment-id }
          {
            patient-id: patient-id,
            doctor: tx-sender,
            treatment-type: treatment-type,
            description: description,
            nano-robots-assigned: nano-robots-count,
            target-area: target-area,
            dosage: dosage,
            duration: duration,
            status: STATUS_PLANNED,
            start-date: none,
            completion-date: none,
            side-effects: none
          }
        )

        (var-set next-treatment-id (+ treatment-id u1))
        (ok treatment-id)
      )
      ERR_PATIENT_NOT_FOUND
    )
  )
)

;; Start treatment
(define-public (start-treatment (treatment-id uint))
  (match (map-get? medical-treatments { treatment-id: treatment-id })
    treatment-data
    (begin
      (asserts! (is-eq tx-sender (get doctor treatment-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status treatment-data) STATUS_PLANNED) ERR_UNAUTHORIZED)

      (map-set medical-treatments
        { treatment-id: treatment-id }
        (merge treatment-data {
          status: STATUS_ACTIVE,
          start-date: (some block-height)
        })
      )

      (map-set treatment-progress
        { treatment-id: treatment-id }
        {
          progress-percentage: u0,
          vital-signs: "stable",
          effectiveness: u0,
          last-update: block-height,
          notes: "Treatment initiated"
        }
      )

      (ok true)
    )
    ERR_TREATMENT_NOT_FOUND
  )
)

;; Update treatment progress
(define-public (update-treatment-progress
  (treatment-id uint)
  (progress-percentage uint)
  (vital-signs (string-ascii 100))
  (effectiveness uint)
  (notes (string-ascii 300))
)
  (match (map-get? medical-treatments { treatment-id: treatment-id })
    treatment-data
    (begin
      (asserts! (is-eq tx-sender (get doctor treatment-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status treatment-data) STATUS_ACTIVE) ERR_UNAUTHORIZED)
      (asserts! (<= progress-percentage u100) ERR_INVALID_DOSAGE)

      (map-set treatment-progress
        { treatment-id: treatment-id }
        {
          progress-percentage: progress-percentage,
          vital-signs: vital-signs,
          effectiveness: effectiveness,
          last-update: block-height,
          notes: notes
        }
      )

      ;; Auto-complete if 100% progress
      (if (is-eq progress-percentage u100)
        (complete-treatment treatment-id)
        (ok true)
      )
    )
    ERR_TREATMENT_NOT_FOUND
  )
)

;; Complete treatment
(define-public (complete-treatment (treatment-id uint))
  (match (map-get? medical-treatments { treatment-id: treatment-id })
    treatment-data
    (begin
      (asserts! (is-eq tx-sender (get doctor treatment-data)) ERR_UNAUTHORIZED)
      (asserts! (not (is-eq (get status treatment-data) STATUS_COMPLETED)) ERR_TREATMENT_COMPLETED)

      (map-set medical-treatments
        { treatment-id: treatment-id }
        (merge treatment-data {
          status: STATUS_COMPLETED,
          completion-date: (some block-height)
        })
      )
      (ok true)
    )
    ERR_TREATMENT_NOT_FOUND
  )
)

;; Deploy nano-medical robot
(define-public (deploy-medical-robot
  (robot-id uint)
  (treatment-id uint)
  (robot-type (string-ascii 50))
  (payload (string-ascii 100))
  (target-coordinates (string-ascii 50))
)
  (match (map-get? medical-treatments { treatment-id: treatment-id })
    treatment-data
    (begin
      (asserts! (is-eq tx-sender (get doctor treatment-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status treatment-data) STATUS_ACTIVE) ERR_UNAUTHORIZED)

      (map-set nano-medical-robots
        { robot-id: robot-id }
        {
          treatment-id: treatment-id,
          robot-type: robot-type,
          payload: payload,
          target-coordinates: target-coordinates,
          deployment-date: block-height,
          status: STATUS_ACTIVE,
          battery-level: u100,
          mission-progress: u0
        }
      )
      (ok true)
    )
    ERR_TREATMENT_NOT_FOUND
  )
)

;; Record side effects
(define-public (record-side-effects (treatment-id uint) (side-effects (string-ascii 200)))
  (match (map-get? medical-treatments { treatment-id: treatment-id })
    treatment-data
    (begin
      (asserts! (is-eq tx-sender (get doctor treatment-data)) ERR_UNAUTHORIZED)

      (map-set medical-treatments
        { treatment-id: treatment-id }
        (merge treatment-data { side-effects: (some side-effects) })
      )
      (ok true)
    )
    ERR_TREATMENT_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-patient (patient-id uint))
  (map-get? patients { patient-id: patient-id })
)

(define-read-only (get-treatment (treatment-id uint))
  (map-get? medical-treatments { treatment-id: treatment-id })
)

(define-read-only (get-treatment-progress (treatment-id uint))
  (map-get? treatment-progress { treatment-id: treatment-id })
)

(define-read-only (get-medical-robot (robot-id uint))
  (map-get? nano-medical-robots { robot-id: robot-id })
)

(define-read-only (is-treatment-active (treatment-id uint))
  (match (map-get? medical-treatments { treatment-id: treatment-id })
    treatment-data (ok (is-eq (get status treatment-data) STATUS_ACTIVE))
    ERR_TREATMENT_NOT_FOUND
  )
)
