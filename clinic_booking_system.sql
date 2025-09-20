-- Clinic Booking System - Full SQL Schema

DROP DATABASE IF EXISTS clinic_booking_system;
CREATE DATABASE clinic_booking_system
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE clinic_booking_system;

-- Reference / lookup tables
-- --------------------------------------------------

-- Roles for application users (admin, receptionist, doctor, patient, etc.)
DROP TABLE IF EXISTS roles;
CREATE TABLE roles (
  role_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(255)
) ENGINE=InnoDB;

-- Many common appointment statuses
DROP TABLE IF EXISTS appointment_statuses;
CREATE TABLE appointment_statuses (
  status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status_name VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(255)
) ENGINE=InnoDB;

-- Medical specialities for doctors
DROP TABLE IF EXISTS specialties;
CREATE TABLE specialties (
  specialty_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255)
) ENGINE=InnoDB;

-- Allergy list (optional)
DROP TABLE IF EXISTS allergies;
CREATE TABLE allergies (
  allergy_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Medications
DROP TABLE IF EXISTS medications;
CREATE TABLE medications (
  medication_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  manufacturer VARCHAR(150),
  ndc_code VARCHAR(50),
  UNIQUE (name, manufacturer)
) ENGINE=InnoDB;

-- Core entities: users, patients, doctors, clinics, rooms
-- --------------------------------------------------

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_id SMALLINT UNSIGNED NOT NULL,
  username VARCHAR(80) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(30),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Patients (extends users: one-to-one optional relationship)
DROP TABLE IF EXISTS patients;
CREATE TABLE patients (
  patient_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL UNIQUE,
  date_of_birth DATE,
  gender ENUM('Male','Female','Other') DEFAULT 'Other',
  address VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  postal_code VARCHAR(20),
  emergency_contact_name VARCHAR(150),
  emergency_contact_phone VARCHAR(30),
  CONSTRAINT fk_patient_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Doctors (extends users: one-to-one optional relationship)
DROP TABLE IF EXISTS doctors;
CREATE TABLE doctors (
  doctor_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL UNIQUE,
  license_number VARCHAR(100) NOT NULL UNIQUE,
  license_state VARCHAR(50),
  bio TEXT,
  years_experience TINYINT UNSIGNED,
  CONSTRAINT fk_doctor_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Clinics (locations)
DROP TABLE IF EXISTS clinics;
CREATE TABLE clinics (
  clinic_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  address VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  postal_code VARCHAR(20),
  phone VARCHAR(30),
  UNIQUE (name, address)
) ENGINE=InnoDB;

-- Rooms inside clinics (for bookings / appointment locations)
DROP TABLE IF EXISTS rooms;
CREATE TABLE rooms (
  room_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  clinic_id INT UNSIGNED NOT NULL,
  room_code VARCHAR(50) NOT NULL,
  description VARCHAR(255),
  CONSTRAINT uq_room_code_clinic UNIQUE (clinic_id, room_code),
  CONSTRAINT fk_room_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Relationships: many-to-many between doctors and specialties
-- --------------------------------------------------
DROP TABLE IF EXISTS doctor_specialties;
CREATE TABLE doctor_specialties (
  doctor_id INT UNSIGNED NOT NULL,
  specialty_id SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (doctor_id, specialty_id),
  CONSTRAINT fk_ds_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ds_specialty FOREIGN KEY (specialty_id) REFERENCES specialties(specialty_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Patients allergies (many-to-many)
DROP TABLE IF EXISTS patient_allergies;
CREATE TABLE patient_allergies (
  patient_id INT UNSIGNED NOT NULL,
  allergy_id SMALLINT UNSIGNED NOT NULL,
  noted_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (patient_id, allergy_id),
  CONSTRAINT fk_pa_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pa_allergy FOREIGN KEY (allergy_id) REFERENCES allergies(allergy_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Scheduling: availabilities and appointments
-- --------------------------------------------------

-- Doctor availability slots (recurring patterns and ad-hoc availability)
DROP TABLE IF EXISTS doctor_availabilities;
CREATE TABLE doctor_availabilities (
  availability_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT UNSIGNED NOT NULL,
  clinic_id INT UNSIGNED,
  day_of_week TINYINT, -- 0 = Sunday ... 6 = Saturday; NULL for one-off
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  start_date DATE, -- for a date-bounded availability (optional)
  end_date DATE,
  is_recurring BOOLEAN DEFAULT TRUE,
  notes VARCHAR(255),
  CONSTRAINT fk_da_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_da_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Appointments (bookings). One patient, one doctor, optionally a room.
DROP TABLE IF EXISTS appointments;
CREATE TABLE appointments (
  appointment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  doctor_id INT UNSIGNED NOT NULL,
  clinic_id INT UNSIGNED NOT NULL,
  room_id INT UNSIGNED,
  scheduled_start DATETIME NOT NULL,
  scheduled_end DATETIME NOT NULL,
  status_id TINYINT UNSIGNED NOT NULL DEFAULT 1,
  created_by INT UNSIGNED, -- user who created the booking (receptionist, patient)
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  notes TEXT,
  CONSTRAINT fk_app_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_app_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_app_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_app_room FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_app_status FOREIGN KEY (status_id) REFERENCES appointment_statuses(status_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_app_creator FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
  -- ensure appointment times are sensible
  CHECK (scheduled_end > scheduled_start)
) ENGINE=InnoDB;

-- To prevent double-booking of the same room at overlapping times (approximate enforcement via unique constraint on timespan not feasible in SQL standard)
-- Create an index to speed up overlap checks in application logic
CREATE INDEX idx_appointments_room_time ON appointments (room_id, scheduled_start, scheduled_end);
CREATE INDEX idx_appointments_doctor_time ON appointments (doctor_id, scheduled_start, scheduled_end);

-- Medical records, prescriptions and payments
-- --------------------------------------------------

-- Medical records for each visit (one-to-many: appointment -> medical_records)
DROP TABLE IF EXISTS medical_records;
CREATE TABLE medical_records (
  record_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id BIGINT UNSIGNED NOT NULL,
  patient_id INT UNSIGNED NOT NULL,
  doctor_id INT UNSIGNED NOT NULL,
  visit_date DATE NOT NULL,
  chief_complaint VARCHAR(255),
  diagnosis TEXT,
  treatment_plan TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_mr_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_mr_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_mr_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Prescriptions issued per medical record (many-to-many with medications)
DROP TABLE IF EXISTS prescriptions;
CREATE TABLE prescriptions (
  prescription_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  record_id BIGINT UNSIGNED NOT NULL,
  prescribed_by INT UNSIGNED NOT NULL, -- doctor user id
  prescribed_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  CONSTRAINT fk_presc_record FOREIGN KEY (record_id) REFERENCES medical_records(record_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_presc_doctor FOREIGN KEY (prescribed_by) REFERENCES doctors(doctor_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS prescription_items;
CREATE TABLE prescription_items (
  prescription_id BIGINT UNSIGNED NOT NULL,
  medication_id INT UNSIGNED NOT NULL,
  dose VARCHAR(100),
  frequency VARCHAR(100),
  duration VARCHAR(100),
  instructions TEXT,
  PRIMARY KEY (prescription_id, medication_id),
  CONSTRAINT fk_pi_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pi_med FOREIGN KEY (medication_id) REFERENCES medications(medication_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Payments for appointments
DROP TABLE IF EXISTS payments;
CREATE TABLE payments (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  method ENUM('CASH','CARD','INSURANCE','MOBILE') NOT NULL DEFAULT 'CASH',
  paid_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  reference VARCHAR(200),
  CONSTRAINT fk_payment_app FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Audit / auxiliary tables
-- --------------------------------------------------

-- Simple logs for user actions (optional)
DROP TABLE IF EXISTS audit_logs;
CREATE TABLE audit_logs (
  log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED,
  action VARCHAR(100) NOT NULL,
  object_type VARCHAR(100),
  object_id VARCHAR(100),
  details TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Seed some lookup values (optional but helpful)
-- --------------------------------------------------

INSERT INTO roles (role_name, description) VALUES
  ('Admin','System administrator'),
  ('Receptionist','Booking & check-in'),
  ('Doctor','Medical practitioner'),
  ('Patient','Clinic patient');

INSERT INTO appointment_statuses (status_name, description) VALUES
  ('Scheduled','Appointment is scheduled'),
  ('Checked-in','Patient checked in'),
  ('Completed','Appointment completed'),
  ('Cancelled','Appointment cancelled by patient or staff'),
  ('No-show','Patient did not arrive');

INSERT INTO specialties (name, description) VALUES
  ('General Practice','Primary care physicians'),
  ('Pediatrics','Child health'),
  ('Dermatology','Skin specialists');

INSERT INTO allergies (name) VALUES
  ('Penicillin'),('Peanuts'),('Latex');

-- Example constraints & notes
-- --------------------------------------------------
-- Notes for implementers:
--  * Overlapping appointments should be validated at application level using the indexed columns (doctor_id/room_id + start/end).
--  * For recurring availabilities, combine day_of_week with start_time/end_time. Use doctor_availabilities for quick calendar generation.
--  * Authentication and password storage: password_hash assumes a secure salted hash (e.g., bcrypt) stored by the application.

-- End of clinic_booking_system.sql
