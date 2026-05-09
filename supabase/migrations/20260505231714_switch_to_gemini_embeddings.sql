-- Update embedding column for Gemini (text-embedding-004 uses 768 dimensions)
ALTER TABLE notes 
ALTER COLUMN embedding TYPE VECTOR(768);
