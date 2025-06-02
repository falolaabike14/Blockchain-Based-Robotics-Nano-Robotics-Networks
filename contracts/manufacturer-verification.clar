;; Manufacturer Verification Contract
;; Validates nano-robotics systems and manufacturers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MANUFACTURER_EXISTS (err u101))
(define-constant ERR_MANUFACTURER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CERTIFICATION (err u103))

;; Data structures
(define-map manufacturers
  { manufacturer-id: uint }
  {
    name: (string-ascii 100),
    wallet: principal,
    certification-level: uint,
    verified: bool,
    registration-date: uint,
    expiry-date: uint
  }
)

(define-map nano-systems
  { system-id: uint }
  {
    manufacturer-id: uint,
    model: (string-ascii 50),
    specifications: (string-ascii 200),
    safety-rating: uint,
    approved: bool,
    creation-date: uint
  }
)

(define-data-var next-manufacturer-id uint u1)
(define-data-var next-system-id uint u1)

;; Register a new manufacturer
(define-public (register-manufacturer (name (string-ascii 100)) (certification-level uint))
  (let ((manufacturer-id (var-get next-manufacturer-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (< certification-level u6) ERR_INVALID_CERTIFICATION)

    (map-set manufacturers
      { manufacturer-id: manufacturer-id }
      {
        name: name,
        wallet: tx-sender,
        certification-level: certification-level,
        verified: true,
        registration-date: block-height,
        expiry-date: (+ block-height u52560) ;; ~1 year
      }
    )

    (var-set next-manufacturer-id (+ manufacturer-id u1))
    (ok manufacturer-id)
  )
)

;; Register a nano-robotics system
(define-public (register-nano-system
  (manufacturer-id uint)
  (model (string-ascii 50))
  (specifications (string-ascii 200))
  (safety-rating uint)
)
  (let ((system-id (var-get next-system-id)))
    (match (map-get? manufacturers { manufacturer-id: manufacturer-id })
      manufacturer-data
      (begin
        (asserts! (get verified manufacturer-data) ERR_UNAUTHORIZED)
        (asserts! (<= safety-rating u10) ERR_INVALID_CERTIFICATION)

        (map-set nano-systems
          { system-id: system-id }
          {
            manufacturer-id: manufacturer-id,
            model: model,
            specifications: specifications,
            safety-rating: safety-rating,
            approved: (>= safety-rating u7),
            creation-date: block-height
          }
        )

        (var-set next-system-id (+ system-id u1))
        (ok system-id)
      )
      ERR_MANUFACTURER_NOT_FOUND
    )
  )
)

;; Verify manufacturer status
(define-read-only (get-manufacturer (manufacturer-id uint))
  (map-get? manufacturers { manufacturer-id: manufacturer-id })
)

;; Get nano-system details
(define-read-only (get-nano-system (system-id uint))
  (map-get? nano-systems { system-id: system-id })
)

;; Check if system is approved
(define-read-only (is-system-approved (system-id uint))
  (match (map-get? nano-systems { system-id: system-id })
    system-data (ok (get approved system-data))
    ERR_MANUFACTURER_NOT_FOUND
  )
)
