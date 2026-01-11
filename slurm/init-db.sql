-- Create Slurm accounting database schema
-- This will be automatically executed when MySQL container starts for the first time

-- The slurm_acct_db database is already created by the MySQL environment variables
-- We just need to wait for slurmdbd to initialize the schema using sacctmgr

