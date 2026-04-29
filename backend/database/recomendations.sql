CREATE TABLE recommendations (
    id          BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    patient_id  BIGINT UNSIGNED    NOT NULL,
    medis_id    BIGINT UNSIGNED    NOT NULL,
    content     TEXT            NOT NULL,
    is_read     TINYINT(1)      NOT NULL DEFAULT 0,
    created_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    PRIMARY KEY (id),
    KEY idx_rec_patient (patient_id, created_at DESC),
    KEY idx_rec_unread  (patient_id, is_read),

    CONSTRAINT fk_rec_patient
        FOREIGN KEY (patient_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_rec_medis
        FOREIGN KEY (medis_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;