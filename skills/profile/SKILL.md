---
category: workflow
name: profile
description: End-to-end resume tailoring for a specific job description. Use when the user asks to assess, rewrite, improve, or generate a resume against a JD; merge stronger points from another draft; add recent work bullets; create ATS-friendly PDF/DOCX resumes; or write application fields such as headline, summary, and cover letter. Handles resume files, JD text/screenshots, recruiter-friendly formatting, keyword mapping, and final artifact quality checks.
paths:
  - "**/*resume*.docx"
  - "**/*resume*.pdf"
  - "**/*resume*.md"
  - "**/*cv*.docx"
---

# Resume JD Tailor

Use this skill to turn an existing resume plus a target job description into an application-ready resume and supporting application text. Prioritize truthful positioning, job-description alignment, clean formatting, and artifact quality.

## Core Principles

- Use only evidence from the user's resume, uploaded drafts, explicit user notes, and the job description. Do not invent employers, dates, credentials, metrics, technologies, management scope, security controls, or business outcomes.
- When the user provides new bullet points and says they reflect recent work, treat them as user-confirmed facts, but preserve uncertainty if any claim appears ambiguous.
- **Interview backtrack test:** for any bullet reframed toward the JD's language, check whether the user could comfortably explain it in an interview without backtracking ("well, what I actually meant was..."). Reordering, natural synonyms, and emphasis shifts are fine. Combining adjacent experience into a claim that implies direct experience, or borrowing the JD's exact terminology for work that was only adjacent, is not. Flag borderline bullets to the user with "this is a stretch because X, keep/soften/drop?" instead of silently rewriting them.
- Any company-specific claim used in a summary, headline, or cover letter (products, partnerships, recent news, tech stack) must be verified against the job posting or a fetched source before inclusion. Do not state it from general knowledge or assumption.
- Optimize for the target job without making the resume look artificially keyword-stuffed.
- Preserve the user's strongest technical identity while repositioning the language toward the specific role.
- Keep resume content recruiter-readable: strong technical keywords, concrete scope, clear outcomes, and concise bullets.
- Separate application materials from analysis. Never place match assessments, notes to the user, or rationale inside the final resume.

## Intake Workflow

1. Gather the available inputs:
   - current resume, preferably `.docx` or PDF;
   - target job description text or screenshots;
   - optional secondary draft from another tool/person;
   - optional recent-work bullets or project notes;
   - optional target constraints such as page count, tone, ATS focus, or industry.
2. If the resume or JD is missing and cannot be inferred from the conversation, ask for the missing input.
3. If the JD is supplied as screenshots, extract the visible role overview, tech stack, responsibilities, work arrangement, compensation if relevant, and keywords. Do not use OCR unless required.
4. Identify the target role archetype — e.g. Technical Lead DevOps, Staff Platform Engineer, SRE Lead, Cloud Infrastructure Architect, Engineering Manager, Security Platform Lead.
5. Produce or internally maintain a JD-to-resume mapping before rewriting:
   - must-have technologies;
   - leadership responsibilities;
   - domain context;
   - keywords likely used by ATS;
   - gaps or weakly represented areas;
   - high-value evidence already present in the resume.

## Resume Tailoring Workflow

### 1. Rewrite the headline

Create a concise headline that matches the target role and top differentiators.

Good patterns:
- `Technical Lead, DevOps | GCP/GKE, Terraform, CI/CD, Observability & Zero-Trust Security`
- `Staff Platform Engineer | Kubernetes, Terraform, Platform Security & SRE`
- `Senior SRE / DevOps Lead | Cloud Infrastructure, CI/CD & Incident Response`

Avoid vague headlines like `Experienced IT Professional` or overloaded headlines longer than one line.

### 2. Rewrite the professional summary

Use 4-6 lines. Include:
- years of experience;
- target role identity;
- strongest matching platforms and tools;
- leadership/mentorship scope;
- measurable outcomes;
- job-specific domains such as observability, incident response, security, CI/CD, or product partnership.

Do not use first person in the resume summary unless the user specifically wants a narrative style.

### 3. Update core competencies

Create grouped competencies aligned to the JD. Keep them readable and ATS-friendly.

Recommended groups for DevOps/SRE/platform roles:
- Platform & Cloud
- CI/CD & Pipelines
- Observability & SRE
- IaC & GitOps
- Security & Identity
- Languages & OS

Formatting rule: avoid wide tables that can overflow PDF pages. Prefer compact two-column tables or grouped text blocks with wrapping enabled.

### 4. Rewrite professional experience

Prioritize the current or most relevant role. Use the JD's language where truthful.

Bullet formula:
`Action verb + scope/context + technologies/process + measurable result or business impact`

Strong bullet examples:
- `Designed and maintained GCP infrastructure using Terraform/Terragrunt in GitOps-aligned workflows, eliminating configuration drift across dev/stage/prod environments.`
- `Drove incident response and blameless postmortem practices with structured runbooks, remediation tracking, and on-call handoff standards to improve MTTR.`
- `Implemented zero-trust workload identity using SPIRE/SVID and GKE Workload Identity Federation, reducing reliance on long-lived service account keys.`

For the most recent role, include 8-12 bullets only when the role is highly relevant. For older roles, use 3-5 bullets focused on transferable impact.

### 5. Incorporate user-provided recent work

When the user provides recent-work bullets, map them into the most relevant current role rather than appending them as a standalone dump.

Recommended mapping categories:
- **Secrets & Security** — security, identity, Okta/OIDC, secrets, compliance, CI/CD hardening.
- **Developer Experience & Platform** — technical vision, dependency mapping, platform automation, impact analysis.
- **CI/CD & Automation** — pipeline ownership, reusable workflows, shared orbs/actions, branch/ruleset governance.
- **Runbook & Culture** — incident response, handoffs, postmortems, standards, mentorship.

Condense overlapping bullets. Preserve impressive numbers such as repo count, node/edge counts, service-team adoption, cost savings, uptime, MTTD, MTTR, and time saved.

### 6. Merge a secondary draft

When the user uploads another draft from Claude, ChatGPT, a recruiter, or an older resume:

1. Extract only the strongest substance:
   - clearer role positioning;
   - JD-aligned keywords;
   - missing but truthful technical scope;
   - metrics or leadership language worth preserving.
2. Reject weak elements:
   - bloated wording;
   - repetitive bullets;
   - generic claims;
   - formatting-heavy tables that break PDF layout;
   - unsupported achievements.
3. Merge the strong content into the cleaner resume structure.
4. Tell the user briefly what was incorporated and what was intentionally avoided.

## JD Alignment Checks

For DevOps / platform / SRE roles, explicitly check whether the tailored resume covers:

- cloud provider named in the JD, especially GCP/GKE if requested;
- Terraform or infrastructure-as-code ownership;
- Kubernetes/container platform operations;
- CI/CD systems such as GitHub Actions, CircleCI, GitLab CI, Jenkins, ArgoCD, or Tekton;
- observability tooling such as Datadog, Grafana, Prometheus, OpenTelemetry, Sentry, or New Relic;
- incident response, on-call, postmortems, SLO/SLI, MTTD, MTTR;
- security collaboration, secrets management, identity, Okta/OIDC/SSO, workload identity, Vault, or Secret Manager;
- cross-team partnership with product engineering and leadership;
- mentoring, standards, runbooks, technical vision, escalation ownership, and culture-building.

## Formatting Standards

Use a clean, professional, ATS-friendly layout.

Default resume structure:

1. Name and contact line
2. Targeted headline
3. Professional Summary
4. Core Competencies
5. Professional Experience
6. Featured Writing / Open Source (if relevant and space allows)
7. Certifications
8. Education

Quality requirements:
- Aim for 2 pages for experienced candidates unless the user requests otherwise.
- Use consistent margins, headings, spacing, date formatting, and bullet indentation.
- Do not use oversized tables, dense borders, graphics, icons, rating bars, or columns that harm ATS parsing.
- Avoid orphan bullets and awkward page breaks.
- Keep older experience concise to protect space for target-role evidence.
- Keep links readable but do not overemphasize them visually.
- Use standard fonts and avoid sharing or embedding custom font files unless already permitted by the environment.

## Artifact Creation and Validation

When generating `.docx` or PDF outputs, use the appropriate document/PDF tooling and follow their instructions. Always inspect the rendered artifact before returning it.

### PDF Generation on macOS (Chrome headless)

The reliable PDF pipeline on macOS is: write an HTML file → convert via Chrome headless. **Do not use pandoc PDF engines** (xelatex, weasyprint) — they require system libraries that are not installed. **Do not use `--headless` (old mode)** — it ignores the no-header flag. The correct command for Chrome 149+:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new \
  --disable-gpu \
  --no-pdf-header-footer \
  --print-to-pdf="/path/to/output.pdf" \
  "file:///path/to/source.html"
```

Key flags:
- `--no-pdf-header-footer` suppresses the date/time stamp and file path Chrome injects by default. `--print-to-pdf-no-header` does NOT work on Chrome 149+ — use `--no-pdf-header-footer`.
- Always use `@page { size: letter portrait; }` in HTML CSS to prevent landscape overflow on pages 2+.
- Use `table-layout: fixed` with explicit column widths on competency tables to prevent horizontal overflow.
- Target 2-page output for experienced candidates; tune via font-size (9.5-10pt), margins (0.55-0.65in), and line-height (1.3-1.35).

Also generate a `.docx` via `pandoc source.md -o output.docx` as an editable companion artifact.

### ATS text-layer verification (PDF)

A visual read of the PDF is not sufficient — ATS parsers read the embedded text layer, which can differ from what's rendered. After the visual check, extract the text layer and inspect it:

```bash
pdftotext -layout output.pdf output.txt
```

Check the extraction for:
- no `(cid:*)` markers or `�` replacement characters, and no text visible in the PDF but missing from the extraction;
- email and phone number present as literal text (an icon-only or hyperlink-only contact detail is invisible to ATS);
- reading order matches the visual page order (multi-column layouts are where this breaks; the default single-column HTML template is safe);
- keyword coverage from the mapping in the Intake Workflow — matched, synonym-only, or genuinely missing, never stuffed.

Delete the `.txt` file after the check. If `pdftotext` is unavailable, skip this check with a one-line warning and rely on the visual read only.

### Content formatting rules

- **Never use em dashes (—) anywhere in resume content.** Use commas, periods, or nothing instead. This applies to certifications, featured writing, bullets, and all other sections.
- Date separators in role headers use ` - ` (space-hyphen-space), not en or em dashes.
- **Cover letters and summaries:** cut cliches and filler ("I am passionate about", "leverage my skills", "hit the ground running", "drive results", "synergies") and unsupported buzzwords. Every claim needs a concrete example or fact behind it.

### Validation checklist

- no clipped text;
- no table overflow beyond the right margin;
- no excessive blank space on any page;
- no split heading separated from its bullets;
- no accidental analysis notes inside the resume;
- no em dashes anywhere;
- ATS text-layer extraction is clean (see ATS text-layer verification above);
- page count is 2 for experienced candidates;
- no Chrome date/time header in the top-left corner;
- all pages are portrait orientation;
- contact/header is visible and professional;
- final PDF opens and renders cleanly.

If the preview shows formatting issues, fix and regenerate before sharing.

## Application Field Generation

When the job portal asks for fields such as headline, summary, or cover letter, generate copy that matches the tailored resume and JD.

### Headline

If the field has a character limit, obey it. For LinkedIn/Workable-style fields (~127 characters), use one line like:

```text
Technical Lead, DevOps | GCP/GKE, Terraform, CI/CD, Observability & Zero-Trust Security
```

### Summary

Use one concise paragraph. Include target role, years of experience, top tools, leadership scope, and why the company/role fits.

### Cover letter

Use 4-6 paragraphs:
1. role interest and company mission alignment;
2. relevant technical background;
3. most relevant recent achievements;
4. leadership/collaboration fit;
5. professional closing.

Keep it specific. Avoid generic phrases like "I am a perfect fit."

## Response Pattern

When returning results to the user, include:

- a brief summary of what was changed;
- any notable match strengths or remaining gaps;
- links to generated artifacts;
- optional paste-ready application fields when useful.

Do not over-explain unless the user asks for detailed assessment.
