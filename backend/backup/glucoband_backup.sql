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
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `predictions_risk`
--

LOCK TABLES `predictions_risk` WRITE;
/*!40000 ALTER TABLE `predictions_risk` DISABLE KEYS */;
INSERT INTO `predictions_risk` VALUES (1,2,'2026-08-30 12:59:57','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 100.0}','rendah',0.0000,'Random Forest 1.0'),(2,2,'2026-08-30 13:00:35','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 134.0}','rendah',0.0800,'Random Forest 1.0'),(3,2,'2026-08-30 13:08:35','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 134.0}','rendah',0.0800,'Random Forest 1.0'),(4,2,'2026-08-30 13:09:25','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 134.0}','rendah',0.0800,'Random Forest 1.0'),(5,2,'2026-08-30 13:12:14','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0000,'Random Forest 1.0'),(6,2,'2026-08-30 13:17:48','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0000,'Random Forest 1.0'),(7,2,'2026-08-30 13:17:56','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0000,'Random Forest 1.0'),(8,2,'2026-08-30 13:18:02','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0600,'Random Forest 1.0'),(9,2,'2026-08-30 13:18:40','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0600,'Random Forest 1.0'),(10,2,'2026-08-30 13:19:15','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0000,'Random Forest 1.0'),(11,2,'2026-08-30 13:21:44','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0000,'Random Forest 1.0'),(12,3,'2026-08-30 13:23:15','{\"age\": 20, \"bmi\": 14.872099940511603, \"gender\": \"Female\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 101.0}','rendah',0.0000,'Random Forest 1.0'),(13,3,'2026-08-30 13:26:12','{\"age\": 20, \"bmi\": 14.872099940511603, \"gender\": \"Female\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 100.0}','rendah',0.0000,'Random Forest 1.0'),(14,2,'2026-08-30 13:27:21','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 108.0}','rendah',0.0000,'Random Forest 1.0'),(15,2,'2026-08-30 13:31:00','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 75.0}','rendah',0.0000,'Random Forest 1.0'),(16,2,'2026-08-30 13:31:45','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 50.0}','rendah',0.0000,'Random Forest 1.0'),(17,2,'2026-08-30 13:32:01','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 50.0}','rendah',0.0000,'Random Forest 1.0'),(18,2,'2026-08-30 13:32:09','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 44.0}','rendah',0.0000,'Random Forest 1.0'),(19,2,'2026-08-30 13:32:34','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 96.0}','rendah',0.0000,'Random Forest 1.0'),(20,2,'2026-08-30 13:33:01','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 105.0}','rendah',0.0000,'Random Forest 1.0'),(21,2,'2026-08-30 13:35:51','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 98.0}','rendah',0.0000,'Random Forest 1.0'),(22,2,'2026-08-30 13:36:41','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 98.0}','rendah',0.0600,'Random Forest 1.0'),(23,2,'2026-08-30 13:36:47','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 98.0}','rendah',0.0600,'Random Forest 1.0'),(24,2,'2026-08-30 13:36:52','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 1, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 98.0}','rendah',0.0800,'Random Forest 1.0'),(25,2,'2026-08-30 13:37:12','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"smoking_history\": 1, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 240.0}','tinggi',0.7400,'Random Forest 1.0'),(26,2,'2026-08-30 13:42:22','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 100.0}','rendah',0.0000,'Random Forest 1.0'),(27,2,'2026-08-30 13:44:02','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 146.0}','rendah',0.0000,'Random Forest 1.0'),(28,2,'2026-08-30 13:49:27','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 97.0}','rendah',0.0000,'Random Forest 1.0'),(29,2,'2026-08-30 13:53:13','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 110.0}','rendah',0.0000,'Random Forest 1.0'),(30,2,'2026-08-30 13:54:36','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 103.0}','rendah',0.0000,'Random Forest 1.0'),(31,2,'2026-08-30 13:56:17','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 122.0}','rendah',0.0000,'Random Forest 1.0'),(32,2,'2026-08-30 14:16:22','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 122.0}','rendah',0.0000,'Random Forest 1.0'),(33,2,'2026-08-30 14:16:33','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 122.0}','rendah',0.0000,'Random Forest 1.0'),(34,2,'2026-09-01 13:39:04','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 96.0}','rendah',0.0000,'Random Forest 1.0'),(35,2,'2026-09-01 14:25:35','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 96.0}','rendah',0.0000,'Random Forest 1.0'),(36,2,'2026-09-01 14:30:53','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 92.0}','rendah',0.0000,'Random Forest 1.0'),(37,2,'2026-09-01 14:41:44','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 92.0}','rendah',0.0000,'Random Forest 1.0'),(38,2,'2026-09-01 14:46:33','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 99.0}','rendah',0.0000,'Random Forest 1.0'),(39,2,'2026-09-01 14:52:18','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 101.0}','rendah',0.0000,'Random Forest 1.0'),(40,2,'2026-09-01 15:55:52','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 96.0}','rendah',0.0000,'Random Forest 1.0'),(41,2,'2026-09-01 16:01:34','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 95.0}','rendah',0.0000,'Random Forest 1.0'),(42,2,'2026-09-01 16:04:08','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 95.0}','rendah',0.0000,'Random Forest 1.0'),(43,2,'2026-09-03 05:53:30','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 97.0}','rendah',0.0000,'Random Forest 1.0'),(44,2,'2026-09-03 06:37:14','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 99.0}','rendah',0.0000,'Random Forest 1.0'),(45,2,'2026-09-03 06:42:55','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 102.0}','rendah',0.0000,'Random Forest 1.0'),(46,2,'2026-09-03 06:51:14','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"smoking_history\": 0, \"blood_pressure_dia\": 0, \"blood_pressure_sys\": 0, \"blood_glucose_level\": 99.0}','rendah',0.0000,'Random Forest 1.0');
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
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `predictions_trend`
--

LOCK TABLES `predictions_trend` WRITE;
/*!40000 ALTER TABLE `predictions_trend` DISABLE KEYS */;
INSERT INTO `predictions_trend` VALUES (3,3,'2026-08-30 13:26:13','[]','{\"age\": 20, \"bmi\": 14.872099940511603, \"gender\": \"Female\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [90.0, 96.0, 100.0], \"smoking_history\": 0}','[{\"glucose\": 93.11, \"timestamp\": \"2026-08-30T14:26:12.727887\"}, {\"glucose\": 96.95, \"timestamp\": \"2026-08-30T15:26:12.727887\"}, {\"glucose\": 97.48, \"timestamp\": \"2026-08-30T16:26:12.727887\"}, {\"glucose\": 95.01, \"timestamp\": \"2026-08-30T17:26:12.727887\"}, {\"glucose\": 96.94, \"timestamp\": \"2026-08-30T18:26:12.727887\"}, {\"glucose\": 96.72, \"timestamp\": \"2026-08-30T19:26:12.727887\"}]',6,'1.0',NULL),(14,2,'2026-08-30 13:36:53','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 1, \"heart_disease\": 1, \"glucose_history\": [103.0, 96.0, 98.0], \"smoking_history\": 1}','[{\"glucose\": 99.9, \"timestamp\": \"2026-08-30T14:36:53.211095\"}, {\"glucose\": 97.01, \"timestamp\": \"2026-08-30T15:36:53.211095\"}, {\"glucose\": 98.41, \"timestamp\": \"2026-08-30T16:36:53.211095\"}, {\"glucose\": 98.73, \"timestamp\": \"2026-08-30T17:36:53.211095\"}, {\"glucose\": 97.61, \"timestamp\": \"2026-08-30T18:36:53.211095\"}, {\"glucose\": 98.36, \"timestamp\": \"2026-08-30T19:36:53.211095\"}]',6,'1.0',NULL),(18,2,'2026-08-30 13:53:13','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [101.0, 105.0, 110.0], \"smoking_history\": 0}','[{\"glucose\": 101.94, \"timestamp\": \"2026-08-30T14:53:13.241268\"}, {\"glucose\": 104.46, \"timestamp\": \"2026-08-30T15:53:13.241268\"}, {\"glucose\": 105.02, \"timestamp\": \"2026-08-30T16:53:13.241268\"}, {\"glucose\": 101.94, \"timestamp\": \"2026-08-30T17:53:13.241268\"}, {\"glucose\": 103.01, \"timestamp\": \"2026-08-30T18:53:13.241268\"}, {\"glucose\": 102.65, \"timestamp\": \"2026-08-30T19:53:13.241268\"}]',6,'1.0',NULL),(19,2,'2026-08-30 13:54:37','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [110.0, 105.0, 103.0], \"smoking_history\": 0}','[{\"glucose\": 105.7, \"timestamp\": \"2026-08-30T14:54:36.656053\"}, {\"glucose\": 103.08, \"timestamp\": \"2026-08-30T15:54:36.656053\"}, {\"glucose\": 102.58, \"timestamp\": \"2026-08-30T16:54:36.656053\"}, {\"glucose\": 103.18, \"timestamp\": \"2026-08-30T17:54:36.656053\"}, {\"glucose\": 101.93, \"timestamp\": \"2026-08-30T18:54:36.656053\"}, {\"glucose\": 101.75, \"timestamp\": \"2026-08-30T19:54:36.656053\"}]',6,'1.0',NULL),(20,2,'2026-08-30 13:56:18','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [110.0, 120.0, 122.0], \"smoking_history\": 0}','[{\"glucose\": 116.7, \"timestamp\": \"2026-08-30T14:56:17.985247\"}, {\"glucose\": 121.61, \"timestamp\": \"2026-08-30T15:56:17.985247\"}, {\"glucose\": 121.58, \"timestamp\": \"2026-08-30T16:56:17.985247\"}, {\"glucose\": 120.27, \"timestamp\": \"2026-08-30T17:56:17.985247\"}, {\"glucose\": 122.48, \"timestamp\": \"2026-08-30T18:56:17.985247\"}, {\"glucose\": 122.3, \"timestamp\": \"2026-08-30T19:56:17.985247\"}]',6,'1.0',NULL),(21,2,'2026-08-30 14:16:23','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [110.0, 120.0, 122.0], \"smoking_history\": 0}','[{\"glucose\": 116.7, \"timestamp\": \"2026-08-30T15:16:23.290354\"}, {\"glucose\": 121.61, \"timestamp\": \"2026-08-30T16:16:23.290354\"}, {\"glucose\": 121.58, \"timestamp\": \"2026-08-30T17:16:23.290354\"}, {\"glucose\": 120.27, \"timestamp\": \"2026-08-30T18:16:23.290354\"}, {\"glucose\": 122.48, \"timestamp\": \"2026-08-30T19:16:23.290354\"}, {\"glucose\": 122.3, \"timestamp\": \"2026-08-30T20:16:23.290354\"}]',6,'1.0',NULL),(22,2,'2026-08-30 14:16:34','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [110.0, 100.0, 122.0], \"smoking_history\": 0}','[{\"glucose\": 106.47, \"timestamp\": \"2026-08-30T15:16:34.331462\"}, {\"glucose\": 105.72, \"timestamp\": \"2026-08-30T16:16:34.331462\"}, {\"glucose\": 118.29, \"timestamp\": \"2026-08-30T17:16:34.331462\"}, {\"glucose\": 105.82, \"timestamp\": \"2026-08-30T18:16:34.331462\"}, {\"glucose\": 108.05, \"timestamp\": \"2026-08-30T19:16:34.331462\"}, {\"glucose\": 114.21, \"timestamp\": \"2026-08-30T20:16:34.331462\"}]',6,'1.0',NULL),(23,2,'2026-09-01 13:39:06','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [100.0, 102.0, 96.0], \"smoking_history\": 0}','[{\"glucose\": 99.81, \"timestamp\": \"2026-09-01T14:39:05.489301\"}, {\"glucose\": 99.62, \"timestamp\": \"2026-09-01T15:39:05.489301\"}, {\"glucose\": 97.42, \"timestamp\": \"2026-09-01T16:39:05.489301\"}, {\"glucose\": 99.21, \"timestamp\": \"2026-09-01T17:39:05.489301\"}, {\"glucose\": 98.64, \"timestamp\": \"2026-09-01T18:39:05.489301\"}, {\"glucose\": 97.85, \"timestamp\": \"2026-09-01T19:39:05.489301\"}]',6,'1.0',NULL),(24,2,'2026-09-01 14:25:36','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [90.0, 103.0, 96.0], \"smoking_history\": 0}','[{\"glucose\": 94.84, \"timestamp\": \"2026-09-01T15:25:36.402713\"}, {\"glucose\": 99.76, \"timestamp\": \"2026-09-01T16:25:36.402713\"}, {\"glucose\": 96.11, \"timestamp\": \"2026-09-01T17:25:36.402713\"}, {\"glucose\": 96.53, \"timestamp\": \"2026-09-01T18:25:36.402713\"}, {\"glucose\": 98.14, \"timestamp\": \"2026-09-01T19:25:36.402713\"}, {\"glucose\": 96.49, \"timestamp\": \"2026-09-01T20:25:36.402713\"}]',6,'1.0',NULL),(25,2,'2026-09-01 14:30:54','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [100.0, 96.0, 92.0], \"smoking_history\": 0}','[{\"glucose\": 97.85, \"timestamp\": \"2026-09-01T22:00:00+07:00\"}, {\"glucose\": 95.07, \"timestamp\": \"2026-09-01T23:00:00+07:00\"}, {\"glucose\": 94.33, \"timestamp\": \"2026-09-02T00:00:00+07:00\"}, {\"glucose\": 96.58, \"timestamp\": \"2026-09-02T01:00:00+07:00\"}, {\"glucose\": 95.14, \"timestamp\": \"2026-09-02T02:00:00+07:00\"}, {\"glucose\": 95.27, \"timestamp\": \"2026-09-02T03:00:00+07:00\"}]',6,'1.0',NULL),(26,2,'2026-09-01 14:41:44','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [100.0, 95.0, 92.0], \"smoking_history\": 0}','[{\"glucose\": 97.55, \"timestamp\": \"2026-09-01T22:00:00+07:00\"}, {\"glucose\": 94.47, \"timestamp\": \"2026-09-01T23:00:00+07:00\"}, {\"glucose\": 94.17, \"timestamp\": \"2026-09-02T00:00:00+07:00\"}, {\"glucose\": 96.24, \"timestamp\": \"2026-09-02T01:00:00+07:00\"}, {\"glucose\": 94.71, \"timestamp\": \"2026-09-02T02:00:00+07:00\"}, {\"glucose\": 95.03, \"timestamp\": \"2026-09-02T03:00:00+07:00\"}]',6,'1.0',NULL),(27,2,'2026-09-01 14:46:34','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [97.0, 102.0, 99.0], \"smoking_history\": 0}','[{\"glucose\": 98.36, \"timestamp\": \"2026-09-01T22:00:00+07:00\"}, {\"glucose\": 100.27, \"timestamp\": \"2026-09-01T23:00:00+07:00\"}, {\"glucose\": 98.63, \"timestamp\": \"2026-09-02T00:00:00+07:00\"}, {\"glucose\": 98.66, \"timestamp\": \"2026-09-02T01:00:00+07:00\"}, {\"glucose\": 99.29, \"timestamp\": \"2026-09-02T02:00:00+07:00\"}, {\"glucose\": 98.42, \"timestamp\": \"2026-09-02T03:00:00+07:00\"}]',6,'1.0',NULL),(28,2,'2026-09-01 14:52:19','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [98.0, 95.0, 101.0], \"smoking_history\": 0}','[{\"glucose\": 97.27, \"timestamp\": \"2026-09-01T22:00:00+07:00\"}, {\"glucose\": 97.04, \"timestamp\": \"2026-09-01T23:00:00+07:00\"}, {\"glucose\": 99.21, \"timestamp\": \"2026-09-02T00:00:00+07:00\"}, {\"glucose\": 97.3, \"timestamp\": \"2026-09-02T01:00:00+07:00\"}, {\"glucose\": 97.56, \"timestamp\": \"2026-09-02T02:00:00+07:00\"}, {\"glucose\": 98.24, \"timestamp\": \"2026-09-02T03:00:00+07:00\"}]',6,'1.0',NULL),(29,2,'2026-09-01 15:55:53','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [102.0, 100.0, 96.0], \"smoking_history\": 0}','[{\"glucose\": 100.34, \"timestamp\": \"2026-09-01T23:00:00+07:00\"}, {\"glucose\": 98.55, \"timestamp\": \"2026-09-02T00:00:00+07:00\"}, {\"glucose\": 97.46, \"timestamp\": \"2026-09-02T01:00:00+07:00\"}, {\"glucose\": 99.22, \"timestamp\": \"2026-09-02T02:00:00+07:00\"}, {\"glucose\": 98.03, \"timestamp\": \"2026-09-02T03:00:00+07:00\"}, {\"glucose\": 97.82, \"timestamp\": \"2026-09-02T04:00:00+07:00\"}]',6,'1.0',NULL),(30,2,'2026-09-01 16:01:35','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [98.0, 90.0, 95.0], \"smoking_history\": 0}','[{\"glucose\": 95.22, \"timestamp\": \"2026-09-02T00:00:00+07:00\"}, {\"glucose\": 92.19, \"timestamp\": \"2026-09-02T01:00:00+07:00\"}, {\"glucose\": 94.89, \"timestamp\": \"2026-09-02T02:00:00+07:00\"}, {\"glucose\": 94.35, \"timestamp\": \"2026-09-02T03:00:00+07:00\"}, {\"glucose\": 93.4, \"timestamp\": \"2026-09-02T04:00:00+07:00\"}, {\"glucose\": 94.69, \"timestamp\": \"2026-09-02T05:00:00+07:00\"}]',6,'1.0',NULL),(31,2,'2026-09-01 16:04:09','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [98.0, 90.0, 95.0], \"smoking_history\": 0}','[{\"glucose\": 95.22, \"timestamp\": \"2026-09-02T00:00:00+07:00\"}, {\"glucose\": 92.19, \"timestamp\": \"2026-09-02T01:00:00+07:00\"}, {\"glucose\": 94.89, \"timestamp\": \"2026-09-02T02:00:00+07:00\"}, {\"glucose\": 94.35, \"timestamp\": \"2026-09-02T03:00:00+07:00\"}, {\"glucose\": 93.4, \"timestamp\": \"2026-09-02T04:00:00+07:00\"}, {\"glucose\": 94.69, \"timestamp\": \"2026-09-02T05:00:00+07:00\"}]',6,'1.0',NULL),(32,2,'2026-09-03 05:53:32','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [90.0, 95.0, 97.0], \"smoking_history\": 0}','[{\"glucose\": 92.38, \"timestamp\": \"2026-09-03T13:00:00+07:00\"}, {\"glucose\": 95.46, \"timestamp\": \"2026-09-03T14:00:00+07:00\"}, {\"glucose\": 95.47, \"timestamp\": \"2026-09-03T15:00:00+07:00\"}, {\"glucose\": 93.83, \"timestamp\": \"2026-09-03T16:00:00+07:00\"}, {\"glucose\": 95.4, \"timestamp\": \"2026-09-03T17:00:00+07:00\"}, {\"glucose\": 95.08, \"timestamp\": \"2026-09-03T18:00:00+07:00\"}]',6,'1.0',NULL),(33,2,'2026-09-03 06:37:15','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [93.0, 91.0, 99.0], \"smoking_history\": 0}','[{\"glucose\": 93.1, \"timestamp\": \"2026-09-03T14:00:00+07:00\"}, {\"glucose\": 93.9, \"timestamp\": \"2026-09-03T15:00:00+07:00\"}, {\"glucose\": 96.54, \"timestamp\": \"2026-09-03T16:00:00+07:00\"}, {\"glucose\": 93.87, \"timestamp\": \"2026-09-03T17:00:00+07:00\"}, {\"glucose\": 94.88, \"timestamp\": \"2026-09-03T18:00:00+07:00\"}, {\"glucose\": 95.62, \"timestamp\": \"2026-09-03T19:00:00+07:00\"}]',6,'1.0',NULL),(34,2,'2026-09-03 06:42:56','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [105.0, 97.0, 102.0], \"smoking_history\": 0}','[{\"glucose\": 101.48, \"timestamp\": \"2026-09-03T14:00:00+07:00\"}, {\"glucose\": 98.54, \"timestamp\": \"2026-09-03T15:00:00+07:00\"}, {\"glucose\": 100.86, \"timestamp\": \"2026-09-03T16:00:00+07:00\"}, {\"glucose\": 100.07, \"timestamp\": \"2026-09-03T17:00:00+07:00\"}, {\"glucose\": 99.02, \"timestamp\": \"2026-09-03T18:00:00+07:00\"}, {\"glucose\": 100.0, \"timestamp\": \"2026-09-03T19:00:00+07:00\"}]',6,'1.0',NULL),(35,2,'2026-09-03 06:51:15','[]','{\"age\": 22, \"bmi\": 19.5964581216432, \"gender\": \"Male\", \"hypertension\": 0, \"heart_disease\": 0, \"glucose_history\": [109.0, 105.0, 99.0], \"smoking_history\": 0}','[{\"glucose\": 104.8, \"timestamp\": \"2026-09-03T14:00:00+07:00\"}, {\"glucose\": 102.12, \"timestamp\": \"2026-09-03T15:00:00+07:00\"}, {\"glucose\": 100.38, \"timestamp\": \"2026-09-03T16:00:00+07:00\"}, {\"glucose\": 102.41, \"timestamp\": \"2026-09-03T17:00:00+07:00\"}, {\"glucose\": 100.93, \"timestamp\": \"2026-09-03T18:00:00+07:00\"}, {\"glucose\": 100.45, \"timestamp\": \"2026-09-03T19:00:00+07:00\"}]',6,'1.0',NULL);
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
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recommendations`
--

LOCK TABLES `recommendations` WRITE;
/*!40000 ALTER TABLE `recommendations` DISABLE KEYS */;
INSERT INTO `recommendations` VALUES (1,3,1,'Konsumsi makanan bergizi',1,'2026-05-01 04:14:23'),(2,3,1,'makanan bergizi',1,'2026-05-01 04:26:10'),(3,2,1,'Makan ini dong pak',1,'2026-05-01 05:51:49'),(4,3,1,'WOK MAKAN SIANG',1,'2026-05-01 07:15:18'),(5,3,1,'SIANG MAKAN NASI',1,'2026-05-01 07:16:40'),(6,3,1,'makan sore mabok wok',1,'2026-05-01 07:32:11'),(7,3,1,'mabok sore',1,'2026-05-01 08:30:06'),(8,3,1,'makan pagi sore',1,'2026-05-01 08:30:44'),(9,4,1,'ketiduran wok',1,'2026-05-02 04:29:36'),(10,3,1,'siang makan wok',1,'2026-05-04 04:56:04'),(11,3,1,'makan dulu',1,'2026-05-04 04:57:04'),(12,2,1,'makan malam',1,'2026-05-12 14:25:52'),(13,2,1,'sini dulu nak',1,'2026-05-12 14:26:21'),(14,2,1,'halo',1,'2026-05-12 14:26:36'),(15,2,1,'tes',1,'2026-09-01 16:21:34'),(16,2,1,'makan',1,'2026-09-01 16:21:52'),(17,2,1,'makan',1,'2026-09-01 16:22:34'),(18,2,1,'tidur sudah malam',1,'2026-09-01 16:35:35');
/*!40000 ALTER TABLE `recommendations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `settings`
--

DROP TABLE IF EXISTS `settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `settings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `setting_value` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `setting_key` (`setting_key`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `settings`
--

LOCK TABLES `settings` WRITE;
/*!40000 ALTER TABLE `settings` DISABLE KEYS */;
INSERT INTO `settings` VALUES (1,'emergency_contact','081215452982','2026-09-01 13:30:38','2026-09-01 13:31:03');
/*!40000 ALTER TABLE `settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tenaga_medis`
--

DROP TABLE IF EXISTS `tenaga_medis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tenaga_medis` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone_number` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `specialization` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Dokter Umum',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_tenaga_medis_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tenaga_medis`
--

LOCK TABLES `tenaga_medis` WRITE;
/*!40000 ALTER TABLE `tenaga_medis` DISABLE KEYS */;
INSERT INTO `tenaga_medis` VALUES (1,'dr. Rahmat Hidayat, M.Kes., M.Ked','089653197491','Dokter Spesialis Jantung',1,'2026-11-12 08:02:18','2026-11-12 08:02:18');
/*!40000 ALTER TABLE `tenaga_medis` ENABLE KEYS */;
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
  `tenaga_medis_id` bigint unsigned DEFAULT NULL,
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
INSERT INTO `users` (`id`, `name`, `email`, `password`, `role`, `age`, `gender`, `weight_kg`, `height_cm`, `blood_pressure_sys`, `blood_pressure_dia`, `diabetes_history`, `smoking_history`, `is_active`, `fcm_token`, `created_at`, `updated_at`, `tenaga_medis_id`) VALUES (1,'Tenaga Medis','glucoband@home.id','scrypt:32768:8:1$99aAE9xn2rEzoqqn$97eeaf43242b3ba5f61d5c660fbda3d89c7885ad9d0f2713e6144e3a6b255cf96b5cf3e1e33b6bf91b5776fd6a286bbb70a15fbc8086d2ec787292bd64cdd044','tenaga_medis',NULL,NULL,NULL,NULL,NULL,NULL,0,0,1,NULL,'2026-04-28 15:40:59','2026-11-08 10:23:40',NULL),(2,'Arrasyid Atma Wijaya','arrasyidaw3@gmail.com','scrypt:32768:8:1$MrEizRAExVy7hQdy$ee0b8746e8e30b9ffd572a15dec3513d8b4633e7216eb95ddec4a6a935f205d8a7d04d979071d324648c4af04e8efc4aa917aa284c31e0404bd370565287ebbf','pasien',22,'L',54.00,166.00,100,80,0,0,1,NULL,'2026-04-30 02:44:34','2026-11-12 08:02:23',1),(3,'Rhea Alya Khaerunnisa','philocence@gmail.com','12345678','pasien',20,'P',40.00,164.00,100,78,0,0,1,NULL,'2026-05-01 03:09:44','2026-05-01 07:10:14',NULL),(4,'Anisa Anastasya','anisanastasya@gmail.com','tekkomcompile','pasien',20,'P',60.00,163.00,110,80,0,0,1,NULL,'2026-05-01 08:36:03','2026-05-01 08:36:03',NULL);
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

-- Dump completed on 2026-11-14 11:44:21
