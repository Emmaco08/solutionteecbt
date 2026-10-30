-- [SAMPLE] study items for the DEV project only, so the Study tab has something to show (Phase 4A).
-- Delete them when real content arrives:  delete from public.study_items where title like '[SAMPLE]%';
-- No video or PDF files are attached (R2 has none yet), so those items show "not added yet" in the app.
insert into public.study_items (kind, title, subtitle, exam_id, subject_id, year, question_id, body, data, files, is_free, status, sort)
values
  ('note', '[SAMPLE] Indices and logarithms', 'Laws, worked examples and exam tips', 1, 2, null, null,
   E'# The laws of indices\n\nFor any base $a \\neq 0$:\n\n- $a^m \\times a^n = a^{m+n}$\n- $a^m \\div a^n = a^{m-n}$\n- $(a^m)^n = a^{mn}$\n- $a^0 = 1$ and $a^{-n} = \\frac{1}{a^n}$\n\n## Worked example\n\nSimplify $\\frac{2^5 \\times 2^3}{2^6}$.\n\n$$\\frac{2^5 \\times 2^3}{2^6} = 2^{5+3-6} = 2^2 = 4$$\n\n# Logarithms\n\nIf $a^x = N$ then $\\log_a N = x$. The **product law** is $\\log_a (MN) = \\log_a M + \\log_a N$.\n\n> Exam tip: JAMB often asks you to evaluate $\\log_{10} 0.001$. Write $0.001 = 10^{-3}$, so the answer is $-3$.',
   '{}', '{}', true, 'published', 1),
  ('note', '[SAMPLE] Motion: speed, velocity and acceleration', 'Equations of motion with examples', 1, 3, null, null,
   E'# Equations of motion\n\nFor uniform acceleration $a$, starting velocity $u$, final velocity $v$ and time $t$:\n\n- $v = u + at$\n- $s = ut + \\frac{1}{2}at^2$\n- $v^2 = u^2 + 2as$\n\n## Example\n\nA car starts from rest and reaches $20\\,\\text{m/s}$ in $5\\,\\text{s}$. Its acceleration is $a = \\frac{20 - 0}{5} = 4\\,\\text{m/s}^2$.',
   '{}', '{}', false, 'published', 2),
  ('novel', '[SAMPLE] The Lion and the Jewel', 'Wole Soyinka · Drama', 1, 8, null, null,
   'A short sample summary. Sidi, the village belle of Ilujinle, is courted by Lakunle the schoolteacher and by Baroka the old Bale. The play contrasts tradition and change.',
   '{"author":"Wole Soyinka","chapters":[{"title":"Morning","summary":"Lakunle tries to win Sidi, who demands a bride price."},{"title":"Noon","summary":"Sidi sees her pictures in a magazine and grows proud."},{"title":"Night","summary":"Baroka outwits Sidi and she agrees to marry him."}],"themes":[{"title":"Tradition and modernity","text":"Baroka stands for the old ways and Lakunle for foreign ideas."},{"title":"Pride","text":"Sidi''s pride in her beauty sets up the ending."}],"characters":[{"name":"Sidi","text":"The village belle."},{"name":"Lakunle","text":"The young schoolteacher."},{"name":"Baroka","text":"The Bale of Ilujinle."}]}',
   '{}', false, 'published', 1),
  ('video_solution', '[SAMPLE] JAMB 2004 English: lexis and structure', 'Solved step by step', 1, 1, 2004, 'd55ced1e-fd64-4951-aa2b-99ba4b05323c', null,
   '{"duration_s":372}', '{}', false, 'published', 1),
  ('lesson', '[SAMPLE] Quadratic equations', 'Factorisation and the formula', 1, 2, null, null, null,
   '{"duration_s":745}', '{}', false, 'published', 1),
  ('doc', '[SAMPLE] JAMB syllabus: Mathematics', 'Official topics for the UTME', 1, 2, null, null, null,
   '{"pages":24,"topics":[{"title":"Number and numeration","page":2},{"title":"Algebra","page":6},{"title":"Geometry","page":12}]}', '{}', true, 'published', 1);
