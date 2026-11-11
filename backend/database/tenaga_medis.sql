CREATE TABLE IF NOT EXISTS tenaga_medis (
    id              BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    name            VARCHAR(100)       NOT NULL,
    phone_number    VARCHAR(30)        NOT NULL,
    specialization  VARCHAR(100)       NOT NULL DEFAULT 'Dokter Umum',
    is_active       TINYINT(1)         NOT NULL DEFAULT 1,
    created_at      TIMESTAMP          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP          NOT NULL DEFAULT CURRENT_TIMESTAMP
                                       ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    KEY idx_tenaga_medis_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;