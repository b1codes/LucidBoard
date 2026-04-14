-- LucidBoard Database Schema

-- 1. Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Boards Table
CREATE TABLE boards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    title TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 3. Notes Table
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id UUID REFERENCES boards(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    content_text TEXT,
    content_drawing BYTEA,
    color TEXT NOT NULL,
    pos_x FLOAT NOT NULL,
    pos_y FLOAT NOT NULL,
    z_index INTEGER NOT NULL,
    embedding VECTOR(1536), -- Assuming OpenAI/Gemini embedding size
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 4. RPC for Auto-Organize (Clustering Logic)
-- This is a placeholder for actual clustering logic.
-- In a real scenario, you'd use a more complex similarity grouping.
CREATE OR REPLACE FUNCTION match_notes(board_uuid uuid)
RETURNS TABLE (id uuid, new_x float4, new_y float4)
LANGUAGE plpgsql
AS $$
BEGIN
    -- This dummy logic simply spreads notes slightly based on their current position.
    -- Replace this with actual vector-based clustering logic.
    RETURN QUERY
    SELECT 
        n.id, 
        n.pos_x + (random() * 50 - 25)::float4 as new_x, 
        n.pos_y + (random() * 50 - 25)::float4 as new_y
    FROM notes n
    WHERE n.board_id = board_uuid;
END;
$$;
