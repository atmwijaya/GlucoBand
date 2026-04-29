CREATE TABLE devices (
    id              BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    patient_id      BIGINT UNSIGNED    NOT NULL,
    device_code     VARCHAR(64)     NOT NULL,
    firmware_ver    VARCHAR(20),
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    registered_at   TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
 
    PRIMARY KEY (id),
    UNIQUE KEY uq_device_code (device_code),
    KEY idx_patient           (patient_id),

    CONSTRAINT fk_device_patient
        FOREIGN KEY (patient_id) REFERENCES users (id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
