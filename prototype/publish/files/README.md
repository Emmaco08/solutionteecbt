# SolutionTee CBT · Design prototype

**Learn. Think. Solve.** A clickable prototype of the SolutionTee CBT app (JAMB, WAEC and NECO CBT practice) and its admin CMS, shared for review and approval before development starts.

## Review it
- Open the live link (Vercel) on a computer or phone. Start from **Splash** to walk the full student journey, or jump to any screen from the list.
- To comment, tap **Give feedback** (side panel on a computer, the menu button on a phone). A short form opens with the screen filled in. Choose **Needs changes** or **Approved**, write what to change, and add a screenshot if it helps. A free GitHub account is needed.
- All feedback: [Issues](../../issues)

## What is sample content
Plan prices are marked SAMPLE. The featured novel is a placeholder. Questions, passages and the AI replies are written for the prototype. Nothing here is connected to a real backend or payment system.

## Run locally
```bash
node prototype/serve.mjs
```
Then open http://localhost:5173/.

## Notes
- Design tokens (colours, type, spacing, motion) live in `design/tokens.json` and will feed the Flutter app and the website.
- *SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.* Exam-body logos are used only to identify each exam. The Google "G" belongs to Google and is used only on the sign-in button.
- The SolutionTee brand files are © SolutionTee and may not be reused without permission.
