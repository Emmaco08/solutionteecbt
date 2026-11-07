# U3c — JAMB papers always complete, and Use of English set the JAMB way (owner, 2026-11-07)

## The owner's JAMB Use of English pattern (every year, every mode)
| # | Section | Questions | Instruction shown above the section |
|---|---|---|---|
| 1 | Comprehension passage | 5 | Read the passage and answer the questions that follow. |
| 2 | Cloze passage | 10 | Choose the option that best fills each numbered gap in the passage. |
| 3 | JAMB novel | 10 | These questions are based on the JAMB set novel. |
| 4 | Sentence interpretation | 5 | Choose the option that best explains the meaning of each sentence. |
| 5 | Antonyms | 5 | Choose the option opposite in meaning to the word or phrase in italics. |
| 6 | Synonyms | 5 | Choose the option nearest in meaning to the word or phrase in italics. |
| 7 | Basic grammar | 10 | Choose the option that best completes each gap. |
| 8 | Oral English | 10 | Vowels, consonants, stress and rhymes. |
|   | **Total** | **60** | |

Research agrees:
- JAMB's syllabus has three parts: Comprehension/Summary, Lexis and Structure, and Oral Forms.
- Sources list comprehension 5, cloze 10 and the set novel 10, out of 60.
- The pattern is editable in the admin (**Blueprints**), so it can follow a new brochure without a new app.

## What we found in our questions
- Topics do not match the JAMB sections: synonyms and antonyms are one topic (2,340), there is no novel or sentence-interpretation topic, and grammar is spread over 8 topics.
- About 1,000 English questions are bare words ("impossible", "Shine") whose instruction was lost when they were imported, so a student cannot tell if they are synonyms or antonyms.
- Year sizes vary a lot, e.g. Geography 2016 has 493 questions and Geography 2021 has 1; English years have 58–256 questions.

## Build
1. **Sections:**
   - every question gets `section` (English: comprehension, cloze, novel, interpretation, antonyms, synonyms, grammar, oral);
   - `section_source` records who set it: rule, ai or admin;
   - the existing questions are sorted by wording rules first, then the AI for the unclear ones (it uses the correct answer to tell a synonym from an antonym);
   - the admin can change any of them.
2. **Blueprints** (`exam_blueprints`, admin-editable):
   - JAMB Use of English uses the 8 sections above;
   - every other JAMB subject has a plain size of 40.
3. **Complete papers, built on the server** (`cbt_paper`, run as the student so plan locks apply):
   - English follows the blueprint in order: the chosen year first for each section, then other open years. Passage sections take whole passages, and each section's instruction shows above it.
   - Other subjects: if a year has too many questions, a random set of the right size (passage groups kept together). If it has too few, the rest come quietly from other open years. Duplicate questions across years are never repeated.
   - Mixed and quick tests: English follows the same pattern scaled down (e.g. a 20-question English share keeps the same mix).
   - Offline: the phone falls back to what is downloaded.
4. **Admin:**
   - a Blueprints page;
   - a Section field on the English question editor;
   - a `section` column in CSV import (auto-sorted when empty);
   - a "Sort English sections with AI" button for new imports;
   - a per-year report: "2021 English: 4 comprehension, 0 cloze…, filled from other years".
5. **App:**
   - the CBT shows the section instruction above each English section (this fixes bare-word questions);
   - tests use the server's paper.

## Owner checks
- The set novel: novel questions from any year are used. Tell me the current JAMB set novel if only that one should be used.
- Other JAMB subjects: 40 questions each (180 in a full mock).

## Split (token management)
- Lead: SQL, the sorting rules and the AI sorting function.
- Sonnet helpers: the app part and the admin web part.
- Lead: review and checks.
- The web goes live only after the owner says "deploy".
