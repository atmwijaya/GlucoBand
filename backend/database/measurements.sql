CREATE TABLE measurements (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id          BIGINT UNSIGNED    NOT NULL,
    device_id           BIGINT UNSIGNED,
    nir_610nm           FLOAT,
    nir_680nm           FLOAT,
    nir_730nm           FLOAT,
    nir_760nm           FLOAT,
    nir_810nm           FLOAT,
    nir_860nm           FLOAT,
    ppg_heart_rate      FLOAT,
    ppg_spo2            FLOAT,
    ppg_ir_value        FLOAT,
    skin_temp_celsius   DECIMAL(5,2),
    glucose_estimated   DECIMAL(6,2),
    status              ENUM('normal','hipoglikemia','hiperglikemia')
                            GENERATED ALWAYS AS (
                                CASE
                                    WHEN glucose_estimated < 70  THEN 'hipoglikemia'
                                    WHEN glucose_estimated > 200 THEN 'hiperglikemia'
                                    ELSE 'normal'
                                END
                            ) STORED,
    glucose_invasive    DECIMAL(6,2),
    is_calibration      TINYINT(1)      NOT NULL DEFAULT 0,
    created_at         TIMESTAMP        NOT NULL,
    synced_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source              ENUM('wifi','sdcard') NOT NULL DEFAULT 'wifi',
 
    PRIMARY KEY (id),
    KEY idx_patient_time (patient_id, created_at DESC),
    KEY idx_status       (status),
    KEY idx_calibration  (patient_id, is_calibration),
 
    CONSTRAINT fk_meas_patient
        FOREIGN KEY (patient_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_meas_device
        FOREIGN KEY (device_id) REFERENCES devices (id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;