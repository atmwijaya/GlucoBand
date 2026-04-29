CREATE TABLE users (
    id                  BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    name                VARCHAR(100)    NOT NULL,
    email               VARCHAR(150)    NOT NULL,
    password            VARCHAR(255)    NOT NULL,
    role                ENUM('tenaga_medis','pasien') NOT NULL,
    age                 INT(3) UNSIGNED,
    gender              ENUM('L','P'),
    weight_kg           DECIMAL(5,2),
    height_cm           DECIMAL(5,2),
    bmi                 DECIMAL(5,2) GENERATED ALWAYS AS (
                            ROUND(weight_kg / ((height_cm / 100) * (height_cm / 100)), 2)
                        ) STORED,
 
    blood_pressure_sys  SMALLINT UNSIGNED,
    blood_pressure_dia  SMALLINT UNSIGNED,
    diabetes_history    TINYINT(1)      NOT NULL DEFAULT 0,
    smoking_history     TINYINT(1)      NOT NULL DEFAULT 0,
    is_active           TINYINT(1)      NOT NULL DEFAULT 1,
    fcm_token           VARCHAR(255),
    created_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP,
 
    PRIMARY KEY (id),
    UNIQUE KEY uq_email  (email),
    KEY idx_role         (role),
    KEY idx_active       (is_active)
) ENGINE=InnoDB;
