-- Create n8n database and user
-- This script runs automatically on PostgreSQL first startup

-- Create n8n database
CREATE DATABASE n8n;

-- Create n8n user with password
-- NOTE: Change 'changeme' to your secure password
CREATE USER n8n WITH ENCRYPTED PASSWORD 'changeme';

-- Grant all privileges on n8n database to n8n user
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

-- Connect to n8n database and grant schema permissions
\c n8n
GRANT ALL ON SCHEMA public TO n8n;
