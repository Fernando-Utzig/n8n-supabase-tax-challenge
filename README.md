# Tax Document Processing System - Submission

## Overview

This project implements the N8N AI Agent Technical Assessment. The goal is to demonstrate the ability to automate the processing of documents (initially text-based PDFs), audio metadata, and text inputs using N8N and Supabase. The system monitors a Gmail inbox, classifies incoming items, extracts relevant information (text content, basic data via Regex), and stores the results in a structured Supabase database.

## Features Implemented (Part 1)

- **Automated Email Ingestion:** Monitors a Gmail inbox for new messages using the N8N Gmail Trigger.
- **Attachment Handling:** Detects emails with attachments and identifies binary data.
- **Input Type Routing:** Uses N8N Switch node to route processing based on attachment MIME type (Document: PDF, Audio: MP3/WAV, Text: Fallback).
- **PDF Text Extraction:** Extracts text content directly from text-based PDF documents using the "Extract PDF Text" node.
- **Regex-Based Document Classification:** Identifies document type (W-2, 1099-MISC, 1099-NEC, Invoice, etc.) based on keywords found in the extracted text using a Function node.
- **Regex-Based Data Extraction:** Extracts specific data points (e.g., SSN format) from extracted text using a Function node.
- **Supabase Integration:**
  - Stores processed document metadata, extracted text, and extracted data snippets in a `documents` table using the N8N Supabase node.
  - Stores basic metadata for received audio files in an `audio_files` table.
  - Stores basic metadata and content for text-based emails in a `text_inputs` table.
- **Basic Error Handling:** Logs errors during Supabase data insertion using the N8N Log Entry node.
- **Database Schema:**
  - Defined PostgreSQL schema in Supabase for storing data from different input types.
- **(Backend Setup for RAG):**
  - Enabled `pgvector` extension in Supabase.
  - Created SQL function `match_documents` for vector similarity search.
  - Created `find-similar-documents` Edge Function (though not called by N8N in Part 1).
- **(Partial Setup for Image OCR):** Configured AWS credentials and IAM user for AWS Textract (though not currently used in the workflow for OCR).

## Tech Stack

- **Workflow Automation:** N8N (Self-Hosted v1.90.2)
- **Backend & Database:** Supabase (PostgreSQL)
- **Vector Storage:** Supabase pgvector extension
- **Email Integration:** N8N Gmail Node (via Google API / OAuth)
- **Programming Language:** JavaScript (for N8N Function nodes), SQL, TypeScript (for Supabase Edge Functions)
- **Cloud Service Setup (Optional):** AWS (IAM, Credentials for Textract)

## Setup Instructions

### Prerequisites

1. **N8N Instance:** A running N8N instance (Cloud or Self-Hosted).
2. **Supabase Account:** A Supabase project (Free tier is sufficient).
3. **Gmail Account:** A Gmail account for N8N to monitor.
4. **Google Cloud Project:** Credentials (Client ID/Secret) for Gmail API access via OAuth, configured with your monitoring email as a test user during setup.
5. **(Optional for Full OCR):** AWS Account with IAM user credentials configured for Textract access.

### 1. Clone Repository

```bash
git clone <your-github-repo-url>
cd <your-repo-name>
```

### 2. Supabase Setup

1.  **Connect** to your Supabase project database.
2.  **Run Migrations:** Execute the SQL commands found in the repository under `supabase/migrations/`:
    *   `001_initial_schema.sql` (Creates `documents`, `audio_files`, `text_inputs`, `processing_logs` tables and enables `vector` extension).
    *   `002_match_documents_function.sql` (Contains the SQL for the `match_documents` function).
3.  **Deploy Edge Functions:** (Optional for Part 1 submission as inserts use the N8N node, but good practice for API documentation)
    *   Using the Supabase CLI or in-browser editor, deploy the Edge Functions located in the repository under `/supabase/functions` (ensure you have `process-document`, `process-audio`, `process-text`, `find-similar-documents`).
    *   Set necessary Environment Variables/Secrets in Supabase Project Settings -> Edge Functions (e.g., `OPENAI_API_KEY` if you were using it).
4.  **Note API Keys:** Go to Project Settings -> API. Note your `Project URL`, `anon` key, and `service_role` key.

### 3. N8N Setup

1.  **Import Workflow:** Import the `part1_workflow.json` file (located in the `n8n-workflows` directory of the repo) into your N8N instance.
2.  **Configure Credentials:**
    *   **Gmail:** Edit the "Gmail Trigger" node. Select your existing Gmail OAuth credential or create a new one using your Google Cloud Client ID/Secret. Ensure it has permissions to read emails and attachments.
    *   **Supabase:** Edit the "Supabase" nodes (used for creating rows). Select your existing Supabase credential or create a new one using your Supabase `Project URL`, `anon` key, and **`service_role` key**.
    *   **(If using AWS Textract):** Edit the relevant node (currently unused HTTP Request node intended for Textract). Select your existing AWS credential or create one using the IAM Access Key ID and Secret Access Key.
3.  **Verify Node Names:** Ensure the expressions within nodes (especially the `Set` node referencing the trigger) correctly use the names of your nodes (e.g., `Gmail Trigger`, `Switch`). Check paths within expressions like `$node["NODE_NAME"]...`.
4.  **Activate Workflow:** Toggle the workflow to "Active".

## Workflow Logic Breakdown

1.  **`Gmail Trigger`:** Monitors the configured Gmail inbox for new emails using Google's API. Fetches email details, including body and binary attachment data.
2.  **`IF (Has Attachment?)`:** Checks if the incoming item has any binary data (`$binary` object exists and has keys).
    *   **True:** Passes emails *with* attachments to the Switch node.
    *   **False:** (Path not developed in Part 1) Emails without attachments stop here.
3.  **`Switch (Route by Type)`:** Routes items based on the MIME type of the first attachment (`$binary.attachment_0.mimeType`).
    *   **Output 0 (Document):** Matches PDF, JPEG, PNG, JPG.
    *   **Output 1 (Audio):** Matches MP3, WAV, MPEG, OGG, M4A.
    *   **Fallback (Text):** Catches emails with attachments not matching Doc/Audio.
4.  **Document Path (Output 0):**
    *   **`Extract PDF Text`:** Extracts text content from text-based PDFs identified as `attachment_0`.
    *   **`Function (Classify & Extract)`:** Applies Regex rules to the extracted text (`$json.text`) to determine `document_type` (W-2, 1099, Invoice) and extract basic data (`extracted_data.ssn_found`).
    *   **`Set (Format Document Data)`:** Gathers required fields (`filename`, `mime_type` from Trigger node's binary metadata; `document_type`, `extracted_text`, `extracted_data` from Function node) into a clean object.
    *   **`Supabase (Create Document)`:** Inserts a new row into the `documents` table using the formatted data from the Set node. Adds `processing_status: "completed"`.
    *   **`Log Entry (Error)`:** Catches and logs any errors from the Supabase node.
5.  **Audio Path (Output 1):** (Minimally implemented for Part 1)
    *   **`Set (Format Audio Metadata)`:** Prepares basic metadata (`filename`, `source`, `mime_type`). Sets `processing_status` to `pending_transcription`.
    *   **`Supabase (Create Audio)`:** Inserts a row into the `audio_files` table.
    *   **`Log Entry (Error)`:** Logs errors.
    *   *Note: No actual transcription or NLP occurs.*
6.  **Text Path (Fallback):** (Minimally implemented for Part 1)
    *   **`Set (Format Text Data)`:** Prepares basic data (`source`, `source_identifier` (subject), `original_text` (body)). Sets `processing_status` to `completed`.
    *   **`Supabase (Create Text)`:** Inserts a row into the `text_inputs` table.
    *   **`Log Entry (Error)`:** Logs errors.
    *   *Note: No advanced NLP occurs.*

## Supabase Backend Details

### Database Schema

*   **`documents`:** Stores metadata, extracted text, classification, extracted data snippets, and status for processed documents. Includes `embedding` column (for RAG, currently unused) and `processing_status`.
*   **`audio_files`:** Stores metadata for audio files. Includes `transcribed_text` and `extracted_entities` (currently unused).
*   **`text_inputs`:** Stores metadata and content for text-based inputs (emails). Includes `extracted_data` (currently basic/unused).
*   **`processing_logs`:** (Optional) For logging workflow execution details and errors.

### Supabase Edge Functions API

*(Note: N8N currently uses the Supabase node for inserts, but these Edge Functions were created per requirements and could be used for other integrations or API documentation).*

*   **`POST /process-document`**: Expects JSON body (`filename`, `source`, `mime_type`, `document_type`, `extracted_text`, `extracted_data`). Inserts into `documents` table. Requires Service Role key.
*   **`POST /process-audio`**: Expects JSON body (`filename`, `source`, `mime_type`). Inserts into `audio_files` table with null transcription/entities. Requires Service Role key.
*   **`POST /process-text`**: Expects JSON body (`source`, `source_identifier`, `original_text`, `extracted_data`). Inserts into `text_inputs` table. Requires Service Role key.
*   **`POST /find-similar-documents`**: Expects JSON body (`embedding`, `limit`). Calls the `match_documents` SQL function to perform vector similarity search on the `documents` table. Requires Service Role key. (RAG endpoint, not currently called by N8N).

### RAG SQL Function (`match_documents`)

*   A PostgreSQL function created using `plpgsql` and utilizing the `pgvector` extension.
*   Takes a query embedding vector, a similarity threshold, and a result limit as input.
*   Performs a cosine similarity search (`<=>` operator) against the `embedding` column in the `documents` table.
*   Returns the `id`, `filename`, `document_type`, and `similarity` score for matching documents above the threshold.

## Error Handling Implemented

*   The N8N Supabase nodes are configured to use their error output path.
*   Errors during database insertion are logged using the `Log Entry` node (basic file/console logging within N8N).
*   *(Note: Retries on API/DB failure were discussed but need explicit configuration on the Supabase node if not default behavior).*

## Limitations / Skipped Components (Part 1)

*   **Image OCR:** The workflow currently relies on the "Extract PDF Text" node. OCR for image files (JPEG, PNG) or image-based PDFs is not implemented in this flow, although AWS Textract credentials and IAM setup were completed. The HTTP Request node configured for Textract is present but not connected in the main successful path.
*   **Audio Processing:** Due to the lack of access to paid AI services (OpenAI Whisper/alternatives), audio files are detected, metadata is stored, but no transcription or NLP entity extraction is performed.
*   **Text NLP:** Advanced NLP entity extraction from email bodies is not performed beyond basic Regex in the Function node examples.
*   **RAG Implementation:** While the Supabase backend (pgvector, SQL function, Edge Function) is set up for RAG similarity search, the N8N workflow does not currently generate embeddings (requires AI service) or call the `find-similar-documents` endpoint. The `embedding` column in the `documents` table remains null.
*   **Alerts:** Basic logging exists, but advanced alerting (Email/Slack for critical failures) is not implemented in Part 1.

## AI Assistance Usage (Bonus Points)

*   AI Assistant (ChatGPT/Claude model) was used extensively throughout the development of Part 1.
*   **Brainstorming & Planning:** Discussed requirements, planned workflow logic, and database schema design.
*   **Code Generation:**
    *   Generated initial JavaScript code for the N8N Function node (Regex classification/extraction), which was then refined.
    *   Generated initial TypeScript code for Supabase Edge Functions.
    *   Generated SQL for the `match_documents` RAG function.
*   **Node Suggestion & Configuration:** Suggested using the Switch node instead of IF for multi-way branching. Provided guidance on configuring nodes like Gmail Trigger, HTTP Request (for AWS), Set, and Supabase.
*   **Debugging:** Helped diagnose errors (e.g., IMAP trigger issues, `[undefined]` data errors, Supabase constraint violations) by analyzing outputs and suggesting corrected expressions or configurations.
*   **API Knowledge:** Provided details on AWS Textract API (`DetectDocumentText` action, request body structure).
*   **Documentation:** Generated this README structure and content based on developer notes and conversation history.

## How to Test

1.  Ensure N8N workflow is active and Supabase is running.
2.  Send an email to the monitored Gmail address with a **text-based PDF attachment** (e.g., the sample W-2 content saved as PDF).
3.  Observe the N8N execution logs. It should follow the Document path.
4.  Check the `documents` table in Supabase for the newly created record containing extracted text and data.
5.  (Optional) Send an email with an MP3 attachment; check the `audio_files` table for metadata.
6.  (Optional) Send a plain text email; check the `text_inputs` table for the content.

