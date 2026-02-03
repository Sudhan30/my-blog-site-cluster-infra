from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import hashlib
import json
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI()

# Enable CORS for the frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust this to your portfolio domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

CACHE = {}
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://ollama-service:11434")

class FitRequest(BaseModel):
    resume: str = None
    preferences: dict = None
    job: str

    # Fallback to hardcoded/default resume if not provided
    # ideally the frontend sends everything, but we can store a default server-side too
    
def cache_key(data: FitRequest):
    # Create a stable key
    resume_part = data.resume[:50] if data.resume else "no-resume" 
    job_part = data.job[:50] 
    raw = resume_part + json.dumps(data.preferences or {}) + data.job
    return hashlib.sha256(raw.encode()).hexdigest()

PROMPT_TEMPLATE = """
You are a job fit evaluator for a professional portfolio website.
Your task is to evaluate how well the portfolio owner fits a job.

Be objective and evidence based.
Do not assume skills that are not written.
If data is missing, say unknown.

GUIDELINES FOR MATCHING:
1. **Transferrable Skills**: Focus on underlying concepts and domain expertise rather than exact keyword matches.
   - *Cloud Platforms*: Experience in one major provider (AWS, GCP, Azure) IS transferrable to others. (e.g. If job asks for AWS and candidate has GCP, this is a MATCH).
   - *Languages/Frameworks*: Proficiency in comparable technologies implies adaptability (e.g. Java/C# or React/Vue).
2. **Seniority & Experience**: Evaluate potential and scope, not just job titles.
   - *Hierarchy*: "Staff", "Principal", or "Lead" titles indicate a level *above* "Senior". A Staff Engineer is fully qualified for a Senior role.
GUIDELINES FOR INTELLIGENT MATCHING (NO KEYWORD MATCHING):

1. **Category-Based Evaluation**:
   - For every required skill, determine its *functional category* (e.g., "Cloud Provider", "Data Warehouse", "CI/CD").
   - Check if the candidate has strong expertise in *any equivalent tool* within that same category.
   - **Rule**: Expertise in ONE major tool in a category = Qualified for ALL tools in that category.
   - *Example*: GCP experience satisfies an AWS requirement. Jenkins experience satisfies a GitHub Actions requirement.

2. **Concept Over Syntax**:
   - Look for evidence of *concepts* rather than specific tool names.
   - "Data Pipelines" or "ETL" in a resume satisfies requirements for specific tools like "Airflow" or "dbt".
   - "Infrastructure as Code" satisfies Terraform or Pulumi.

3. **Seniority & Adaptability**:
   - If the candidate is **Senior/Staff+**, assume high adaptability.
   - Do NOT mark specific tools as gaps if the candidate has years of experience in the requested *domain* (e.g. Backend, Data, DevOps).


Resume:
{resume}

Preferences:
{preferences}

Job Description:
{job}

TASK
Compare the resume and preferences to the job.
Evaluate skills match, experience level match, domain match, role and career alignment.

SCORING
Give a score from 0 to 100.
90-100: strong fit
70-89: good fit
50-69: partial fit
<50: weak fit

OUTPUT
Return ONLY valid JSON.
{{
"fit_score": 0,
"fit_level": "",
"aligned_areas": [],
"gaps": [],
"summary": "",
"verdict": ""
}}

Keep summary under 80 words.
"""

@app.post("/job-fit")
def job_fit(req: FitRequest):
    # Use provided resume or environment variable equivalent, or error if empty
    # For now, let's assume the frontend sends the full resume text found in the repo
    if not req.resume:
       return {"error": "Resume text is required"}

    key = cache_key(req)
    if key in CACHE:
        print(f"Cache hit for {key}")
        return CACHE[key]

    prompt = PROMPT_TEMPLATE.format(
        resume=req.resume,
        preferences=json.dumps(req.preferences or {}),
        job=req.job
    )

    try:
        print(f"Sending request to Ollama at {OLLAMA_HOST}...")
        r = requests.post(
            f"{OLLAMA_HOST}/api/generate",
            json={
                "model": "gemma:7b", 
                "prompt": prompt,
                "stream": False,
                "temperature": 0.3,
                "format": "json" # Force JSON mode if supported by the model version
            },
            timeout=120
        )
        r.raise_for_status()
        
        # Ollama returns 'response' field
        text = r.json().get("response", "")
        print("Received response from Ollama")

        # Parse JSON from LLM
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            # Fallback cleanup if the model chats a bit (rare with json mode/prompt)
            # Find first { and last }
            start = text.find("{")
            end = text.rfind("}") + 1
            if start != -1 and end != -1:
                 parsed = json.loads(text[start:end])
            else:
                 parsed = {"error": "invalid_json", "raw": text}

        CACHE[key] = parsed
        return parsed

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
def health():
    return {"status": "ok"}
