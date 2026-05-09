-- Migration: Sync Production Schema with SCHEMA.sql
-- Created: 2026-05-05

-- 1. Update boards table
ALTER TABLE IF EXISTS boards 
ADD COLUMN IF NOT EXISTS background_color TEXT DEFAULT '#FFFFFF',
ADD COLUMN IF NOT EXISTS background_layout TEXT DEFAULT 'grid';

-- 2. Update notes table
ALTER TABLE IF EXISTS notes
ADD COLUMN IF NOT EXISTS template TEXT DEFAULT 'plain',
ADD COLUMN IF NOT EXISTS checklist_items JSONB DEFAULT '[]'::jsonb;

-- 3. Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    settings JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid errors on re-run
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
