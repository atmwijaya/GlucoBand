-- MySQL dump 10.13  Distrib 8.0.45, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: glucoband_db
-- ------------------------------------------------------
-- Server version	8.0.45

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `devices`
--

DROP TABLE IF EXISTS `devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `devices` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_id` bigint unsigned NOT NULL,
  `device_code` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `firmware_ver` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `registered_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_device_code` (`device_code`),
  KEY `idx_patient` (`patient_id`),
  CONSTRAINT `fk_device_patient` FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `devices`
--

LOCK TABLES `devices` WRITE;
/*!40000 ALTER TABLE `devices` DISABLE KEYS */;
/*!40000 ALTER TABLE `devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `faq`
--

DROP TABLE IF EXISTS `faq`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `faq` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `question` varchar(300) COLLATE utf8mb4_unicode_ci NOT NULL,
  `answer` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `category` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'umum',
  `order_index` smallint unsigned NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` bigint unsigned NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_faq_active` (`is_active`,`category`,`order_index`),
  KEY `fk_faq_creator` (`created_by`),
  CONSTRAINT `fk_faq_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `faq`
--

LOCK TABLES `faq` WRITE;
/*!40000 ALTER TABLE `faq` DISABLE KEYS */;
INSERT INTO `faq` VALUES (1,'Apa itu GlucoBand?','GlucoBand adalah sarana pemeriksaan kadar gula darah non-invasive berbasis wearable yang memanfaatkan 3 teknologi terkini..','umum',0,1,1,'2026-04-30 11:27:26','2026-04-30 11:54:48'),(2,'Berapa kadar normal gula darah?','Kadar normal gula darah biasanya kisaran 70-200 mg/dL','kesehatan',0,1,1,'2026-05-01 10:56:06','2026-05-01 10:56:06');
/*!40000 ALTER TABLE `faq` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `measurements`
--

DROP TABLE IF EXISTS `measurements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `measurements` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_id` bigint unsigned NOT NULL,
  `device_id` bigint unsigned DEFAULT NULL,
  `nir_610nm` float DEFAULT NULL,
  `nir_680nm` float DEFAULT NULL,
  `nir_730nm` float DEFAULT NULL,
  `nir_760nm` float DEFAULT NULL,
  `nir_810nm` float DEFAULT NULL,
  `nir_860nm` float DEFAULT NULL,
  `ppg_heart_rate` float DEFAULT NULL,
  `ppg_spo2` float DEFAULT NULL,
  `ppg_ir_value` float DEFAULT NULL,
  `skin_temp_celsius` decimal(5,2) DEFAULT NULL,
  `glucose_estimated` decimal(6,2) DEFAULT NULL,
  `status` enum('normal','hipoglikemia','hiperglikemia') COLLATE utf8mb4_unicode_ci GENERATED ALWAYS AS ((case when (`glucose_estimated` < 70) then _utf8mb4'hipoglikemia' when (`glucose_estimated` > 200) then _utf8mb4'hiperglikemia' else _utf8mb4'normal' end)) STORED,
  `glucose_invasive` decimal(6,2) DEFAULT NULL,
  `is_calibration` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL,
  `synced_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `source` enum('wifi','sdcard') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'wifi',
  PRIMARY KEY (`id`),
  KEY `idx_patient_time` (`patient_id`,`created_at` DESC),
  KEY `idx_status` (`status`),
  KEY `idx_calibration` (`patient_id`,`is_calibration`),
  KEY `fk_meas_device` (`device_id`),
  CONSTRAINT `fk_meas_device` FOREIGN KEY (`device_id`) REFERENCES `devices` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_meas_patient` FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `measurements`
--

LOCK TABLES `measurements` WRITE;
/*!40000 ALTER TABLE `measurements` DISABLE KEYS */;
/*!40000 ALTER TABLE `measurements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_id` bigint unsigned NOT NULL,
  `measurement_id` bigint unsigned NOT NULL,
  `type` enum('hipoglikemia','hiperglikemia','system','rekomendasi') COLLATE utf8mb4_unicode_ci NOT NULL,
  `glucose_value` decimal(6,2) NOT NULL,
  `is_sent_patient` tinyint(1) NOT NULL DEFAULT '0',
  `is_sent_medis` tinyint(1) NOT NULL DEFAULT '0',
  `sent_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_patient` (`patient_id`,`created_at` DESC),
  KEY `idx_notif_unsent` (`is_sent_patient`,`is_sent_medis`),
  KEY `fk_notif_measurement` (`measurement_id`),
  CONSTRAINT `fk_notif_measurement` FOREIGN KEY (`measurement_id`) REFERENCES `measurements` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_notif_patient` FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `predictions_risk`
--

DROP TABLE IF EXISTS `predictions_risk`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `predictions_risk` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_id` bigint unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `feature_vector` json NOT NULL,
  `risk_level` enum('rendah','sedang','tinggi') COLLATE utf8mb4_unicode_ci NOT NULL,
  `risk_score` decimal(5,4) NOT NULL,
  `model_version` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '1.0',
  PRIMARY KEY (`id`),
  KEY `idx_risk_patient` (`patient_id`,`created_at` DESC),
  CONSTRAINT `fk_risk_patient` FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `predictions_risk`
--

LOCK TABLES `predictions_risk` WRITE;
/*!40000 ALTER TABLE `predictions_risk` DISABLE KEYS */;
/*!40000 ALTER TABLE `predictions_risk` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `predictions_trend`
--

DROP TABLE IF EXISTS `predictions_trend`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `predictions_trend` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_id` bigint unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `input_measurement_ids` json NOT NULL,
  `health_snapshot` json NOT NULL,
  `predicted_values` json NOT NULL,
  `horizon_hours` tinyint NOT NULL DEFAULT '6',
  `model_version` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '1.0',
  `gen_ai_recommendation` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `idx_trend_patient` (`patient_id`,`created_at` DESC),
  CONSTRAINT `fk_trend_patient` FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `predictions_trend`
--

LOCK TABLES `predictions_trend` WRITE;
/*!40000 ALTER TABLE `predictions_trend` DISABLE KEYS */;
/*!40000 ALTER TABLE `predictions_trend` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recommendations`
--

DROP TABLE IF EXISTS `recommendations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `recommendations` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_id` bigint unsigned NOT NULL,
  `medis_id` bigint unsigned NOT NULL,
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_rec_patient` (`patient_id`,`created_at` DESC),
  KEY `idx_rec_unread` (`patient_id`,`is_read`),
  KEY `fk_rec_medis` (`medis_id`),
  CONSTRAINT `fk_rec_medis` FOREIGN KEY (`medis_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_rec_patient` FOREIGN KEY (`patient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recommendations`
--

LOCK TABLES `recommendations` WRITE;
/*!40000 ALTER TABLE `recommendations` DISABLE KEYS */;
INSERT INTO `recommendations` VALUES (1,3,1,'Konsumsi makanan bergizi',1,'2026-05-01 04:14:23'),(2,3,1,'makanan bergizi',1,'2026-05-01 04:26:10'),(3,2,1,'Makan ini dong pak',1,'2026-05-01 05:51:49'),(4,3,1,'WOK MAKAN SIANG',1,'2026-05-01 07:15:18'),(5,3,1,'SIANG MAKAN NASI',1,'2026-05-01 07:16:40'),(6,3,1,'makan sore mabok wok',1,'2026-05-01 07:32:11'),(7,3,1,'mabok sore',1,'2026-05-01 08:30:06'),(8,3,1,'makan pagi sore',1,'2026-05-01 08:30:44'),(9,4,1,'ketiduran wok',1,'2026-05-02 04:29:36'),(10,3,1,'siang makan wok',1,'2026-05-04 04:56:04'),(11,3,1,'makan dulu',1,'2026-05-04 04:57:04');
/*!40000 ALTER TABLE `recommendations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('tenaga_medis','pasien') COLLATE utf8mb4_unicode_ci NOT NULL,
  `age` int unsigned DEFAULT NULL,
  `gender` enum('L','P') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weight_kg` decimal(5,2) DEFAULT NULL,
  `height_cm` decimal(5,2) DEFAULT NULL,
  `bmi` decimal(5,2) GENERATED ALWAYS AS (round((`weight_kg` / ((`height_cm` / 100) * (`height_cm` / 100))),2)) STORED,
  `blood_pressure_sys` smallint unsigned DEFAULT NULL,
  `blood_pressure_dia` smallint unsigned DEFAULT NULL,
  `diabetes_history` tinyint(1) NOT NULL DEFAULT '0',
  `smoking_history` tinyint(1) NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `fcm_token` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_email` (`email`),
  KEY `idx_role` (`role`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` (`id`, `name`, `email`, `password`, `role`, `age`, `gender`, `weight_kg`, `height_cm`, `blood_pressure_sys`, `blood_pressure_dia`, `diabetes_history`, `smoking_history`, `is_active`, `fcm_token`, `created_at`, `updated_at`) VALUES (1,'Tenaga Medis','glucoband@home.id','admingluband','tenaga_medis',NULL,NULL,NULL,NULL,NULL,NULL,0,0,1,NULL,'2026-04-28 15:40:59','2026-04-30 02:11:02'),(2,'Arrasyid Atma Wijaya','arrasyidaw3@gmail.com','warlok2023','pasien',21,'L',45.00,166.00,100,80,0,0,1,NULL,'2026-04-30 02:44:34','2026-04-30 02:55:04'),(3,'Rhea Alya Khaerunnisa','philocence@gmail.com','12345678','pasien',20,'P',40.00,164.00,100,78,0,0,1,NULL,'2026-05-01 03:09:44','2026-05-01 07:10:14'),(4,'Anisa Anastasya','anisanastasya@gmail.com','tekkomcompile','pasien',20,'P',60.00,163.00,110,80,0,0,1,NULL,'2026-05-01 08:36:03','2026-05-01 08:36:03');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-05-08  9:58:54
