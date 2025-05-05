-- Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create documents table
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT now(),
    filename TEXT NOT NULL,
    source TEXT NOT NULL, -- e.g., 'email', 'upload'
    mime_type TEXT NOT NULL,
    document_type TEXT NOT NULL, -- e.g., 'W-2', '1099', 'Invoice', 'Unknown'
    extracted_text TEXT, -- Nullable
    extracted_data JSONB, -- Nullable, for structured fields
    ocr_confidence FLOAT, -- Nullable
    processing_status TEXT NOT NULL, -- e.g., 'pending', 'processing', 'completed', 'error'
    error_message TEXT, -- Nullable
    embedding VECTOR, -- For RAG, requires pgvector
    consistency_flag BOOLEAN DEFAULT false, -- For RAG
    validation_notes TEXT -- Nullable, For RAG
);

-- Create audio_files table
CREATE TABLE audio_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT now(),
    filename TEXT NOT NULL,
    source TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    transcribed_text TEXT, -- Nullable
    extracted_entities JSONB, -- Nullable, e.g., {"ssns": [...], "income_figures": [...]}
    processing_status TEXT NOT NULL,
    error_message TEXT -- Nullable
);

-- Create text_inputs table
CREATE TABLE text_inputs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT now(),
    source TEXT NOT NULL, -- e.g., 'email', 'form'
    source_identifier TEXT NOT NULL, -- e.g., email subject or ID
    original_text TEXT NOT NULL,
    extracted_data JSONB, -- Nullable
    processing_status TEXT NOT NULL,
    error_message TEXT -- Nullable
);

-- (Optional) Create processing_logs table for debugging/auditing
CREATE TABLE processing_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMPTZ DEFAULT now(),
    workflow_id UUID, -- Foreign key to workflow (if applicable)
    step_name TEXT NOT NULL,
    status TEXT NOT NULL, -- e.g., 'success', 'error'
    message TEXT,
    related_item_id UUID, -- Foreign key to a related item
    related_item_type TEXT -- e.g., 'document', 'audio_file', 'text_input'
);


-- Function to find similar documents using vector cosine similarity
CREATE OR REPLACE FUNCTION match_documents (
  query_embedding vector(1536), -- The embedding vector to search for
  match_threshold float,        -- Minimum similarity score (e.g., 0.7)
  match_count int               -- Maximum number of results to return
)
RETURNS TABLE (
  id uuid,
  filename text,
  document_type text,
  similarity float -- Cosine similarity score
)
LANGUAGE sql STABLE -- Indicates the function doesn't modify the database
AS $$
  SELECT
    documents.id,
    documents.filename,
    documents.document_type,
    -- Calculate cosine similarity: 1 - cosine distance (cosine distance is '<=>')
    1 - (documents.embedding <=> query_embedding) AS similarity
  FROM documents
  -- Ensure embedding column is not null before comparing
  WHERE documents.embedding IS NOT NULL
    -- Filter results to only include those above the threshold
    AND 1 - (documents.embedding <=> query_embedding) > match_threshold
  -- Order by similarity (highest first)
  ORDER BY similarity DESC
  -- Limit the number of results
  LIMIT match_count;
$$;