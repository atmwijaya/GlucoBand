CREATE TABLE predictions_risk (
    id              BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    patient_id      BIGINT UNSIGNED    NOT NULL,
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    feature_vector  JSON            NOT NULL,
    risk_level      ENUM('rendah','sedang','tinggi') NOT NULL,
    risk_score      DECIMAL(5,4)    NOT NULL,
    model_version   VARCHAR(20)     NOT NULL DEFAULT '1.0',
 
    PRIMARY KEY (id),
    KEY idx_risk_patient (patient_id, created_at DESC),
 
    CONSTRAINT fk_risk_patient
        FOREIGN KEY (patient_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;