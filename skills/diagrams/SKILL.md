---
name: diagrams
description: Create, revise, validate, and safely publish clear technical diagrams for architecture, infrastructure, CI/CD, authentication, migrations, and runbooks. Use when converting flow text into a visual, replacing or correcting a diagram, fixing hidden or crowded labels, documenting three or more interacting systems, or adding diagrams to Confluence.
---

# Technical Diagrams

Create diagrams that are accurate at delivery time, readable at the final viewing size, and useful without a long explanation.

## Workflow

1. Identify the one question the diagram must answer.
2. Verify every system, flag, filename, identity, and relationship against current source material. Prefer code and live configuration over memory or old documentation.
3. Choose the smallest suitable format:
   - Use SVG as the canonical source plus PNG for polished Confluence diagrams.
   - Use draw.io when the team needs an editable visual source.
   - Use Mermaid for simple flows and sequence diagrams maintained in Markdown.
   - Use ASCII only for terminal-first or temporary documentation.
4. Sketch the layout before writing prose. Use one reading direction and at most five or six nodes per lane.
5. Reserve whitespace for edge labels. Route connectors around nodes and text.
6. Render the exact output and inspect it visually. Do not deliver an uninspected diagram.
7. Publish safely. Preserve unrelated existing diagrams and screenshots; update only the matching attachment or insert a new image.

Read [references/style-guide.md](references/style-guide.md) before creating a polished wiki diagram or revising an existing one.

## Nonnegotiable Rules

- Never place text behind a node, arrow, border, or callout.
- Never route a connector through a node or label.
- Wrap text manually and size the box for the longest line.
- Use short noun phrases for node titles and verbs for edge labels.
- Use color semantically and consistently; do not use color as decoration.
- Prefer one strong flow per diagram. Split overview and implementation detail when either becomes crowded.
- Include a descriptive title and a one-sentence subtitle that states the takeaway.
- Avoid decorative icons unless they convey information.
- Validate the diagram at the width where readers will see it in Confluence.
- If the code disagrees with the draft, fix the diagram and its surrounding prose together.

## Source Verification

Before drawing, build a small fact table:

| Claim | Source of truth | Verified value |
|---|---|---|
| Feature flags | Current orb or pipeline source | Exact parameter names and environments |
| Identities | Terraform and workload configuration | KSA, GSA, role, or service account |
| Runtime path | Deployment manifests and application config | Actual call sequence |
| Authorization | IAM and database grants | Authentication versus authorization boundary |

Do not infer an environment limitation from an old rollout state. For example, if current orb code exposes dev, stage, and prod flags, show all three even if the first implementation was dev-only.

## Visual System

Use these defaults for technical diagrams:

| Meaning | Fill | Stroke |
|---|---|---|
| Files and configuration | `#EEF4FF` | `#4877C1` |
| Identity and healthy runtime | `#E9F7F0` | `#2F855A` |
| Proxy, CI, or caution | `#FFF4E5` | `#CC7A00` |
| Database and authorization | `#F4EDFF` | `#7654A8` |
| Panels and grouping | `#F7F8FA` | `#DFE1E6` |
| Primary and secondary text | `#172B4D` | `#42526E` |

For a roughly 2000-pixel-wide export, start with a 38–40 px title, 24–26 px section headings, 18–20 px node titles, 14–16 px body text, and 14–15 px edge labels. Increase sizes when the image will appear narrow in Confluence.

## Rendering

Keep SVG as the editable source. To create a PNG when Node.js and `sharp` are available:

```bash
node scripts/render-svg.cjs diagram.svg diagram.png 180
```

The last argument is the render density. Use a high-resolution PNG so Confluence scaling does not make labels blurry.

For draw.io files, validate the XML before opening it:

```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('diagram.drawio')"
```

Then open the file in diagrams.net because XML parsing alone does not prove the layout is readable.

## Visual QA

Inspect the rendered image, not only the source. Confirm:

- all labels are fully visible;
- arrowheads and labels have clear endpoints;
- no connector crosses text or a node;
- line wrapping is intentional;
- colors remain distinguishable without relying on color alone;
- the main path is obvious in a three-second scan;
- the image remains readable at Confluence content width;
- every technical claim matches current source code or configuration.

If any check fails, adjust the source, render again, and re-inspect.

## Confluence Publishing

1. Read the current page before editing it.
2. Preserve existing diagrams, screenshots, captions, and surrounding content unless the user explicitly requests replacement.
3. Add a new attachment or create a new version of the intended attachment only.
4. Insert the image near the section whose text it replaces or clarifies.
5. Add a short caption stating what the reader should notice.
6. Re-read the published page and confirm the image renders in the intended location.
7. When a new Confluence attachment version produces a new media file ID, update the ADF media node to that current file ID.

## Draw.io Safety Rules

- Do not use backslash-escaped quotes inside XML attributes; use `&quot;` or remove the quotes.
- Use only valid XML entities: `&amp;`, `&lt;`, `&gt;`, `&quot;`, and `&apos;`.
- Avoid HTML named entities such as `&rarr;` in XML attributes; use numeric entities or plain ASCII.
- Set `html=1` only when the value intentionally contains HTML.
- Validate after every mechanical XML edit and open the result in diagrams.net.

## Completion Standard

A diagram is complete only when its facts are verified, its rendered output passes visual QA, its source remains editable, and the published page has been checked without disturbing unrelated visuals.
