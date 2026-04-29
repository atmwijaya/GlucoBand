CREATE TABLE predictions_trend (
    id                      BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    patient_id              BIGINT UNSIGNED    NOT NULL,
    created_at              TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    input_measurement_ids   JSON            NOT NULL,
    health_snapshot         JSON            NOT NULL,
    predicted_values        JSON            NOT NULL,
    horizon_hours           TINYINT         NOT NULL DEFAULT 6,
    model_version           VARCHAR(20)     NOT NULL DEFAULT '1.0',
    gen_ai_recommendation   TEXT,
 
    PRIMARY KEY (id),
    KEY idx_trend_patient (patient_id, created_at DESC),
 
    CONSTRAINT fk_trend_patient
        FOREIGN KEY (patient_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;