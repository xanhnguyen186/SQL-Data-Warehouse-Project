/*
=============================================================
Create Database and Schemas (PostgreSQL)
=============================================================
*/

DROP DATABASE IF EXISTS datawarehouse;
CREATE DATABASE datawarehouse;

CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;

