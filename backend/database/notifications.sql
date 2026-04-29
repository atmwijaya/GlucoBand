CREATE TABLE notifications (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id      BIGINT UNSIGNED    NOT NULL,
    measurement_id  BIGINT UNSIGNED NOT NULL,
    type            ENUM('hipoglikemia','hiperglikemia', 'system', 'rekomendasi' ) NOT NULL,
    glucose_value   DECIMAL(6,2)    NOT NULL,
    is_sent_patient TINYINT(1)      NOT NULL DEFAULT 0,
    is_sent_medis   TINYINT(1)      NOT NULL DEFAULT 0,
    sent_at         DATETIME,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    PRIMARY KEY (id),
    KEY idx_notif_patient (patient_id, created_at DESC),
    KEY idx_notif_unsent  (is_sent_patient, is_sent_medis),
 
    CONSTRAINT fk_notif_patient
        FOREIGN KEY (patient_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE,
 
    CONSTRAINT fk_notif_measurement
        FOREIGN KEY (measurement_id) REFERENCES measurements (id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;