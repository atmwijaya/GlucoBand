CREATE TABLE faq (
    id          BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    question    VARCHAR(300)    NOT NULL,
    answer      TEXT            NOT NULL,
    category    VARCHAR(60)     NOT NULL DEFAULT 'umum',
    order_index SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    is_active   TINYINT(1)      NOT NULL DEFAULT 1,
    created_by  BIGINT UNSIGNED NOT NULL,          -- diubah menjadi BIGINT
    created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
 
    PRIMARY KEY (id),
    KEY idx_faq_active    (is_active, category, order_index),
    CONSTRAINT fk_faq_creator
        FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;