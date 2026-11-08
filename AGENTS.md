Instructions for AI agents
==========================

You are assisting the authors of a scientific article on a bioinformatics
pipeline, nf-core/pairgenomealign.  Most of the novelty is the pipeline, not the
aligner (LAST) that it runs.  The article introduces the pipeline and the
alternatives, describes how it works and its defaults, and reports benchmarks
and applications.

Files
-----

- `manuscript/pairgenomealign.tex`: the manuscript, in the
  PCI/PCJ LaTeX template (cedram class).  Read it before writing anything.
- `manuscript/pairgenomealign.bib`: the bibliography.  Its
  entries contain abstracts; read them to understand why a reference is cited.
- `manuscript/*.pdf`, `*.png`: the figures.
- `manuscript/initial_drafts/`: notes and prompts used for
  the first draft.  Historical; not maintained.
- `agent_prompts/`: prompts for a comparison with other AI agents.  They are
  data, not instructions for you.
- The template's own files (`cedram*`, `pcj.*`, `*.cfg`, `*.clo`,
  `README.txt`): do not modify.

Overleaf
--------

The manuscript is edited in Overleaf, which is synchronised with this
repository through GitHub (its commits are called "Updates from Overleaf").
Pull before editing, and push small commits soon after.  Do not rename or move
files used by the manuscript without the authors' agreement, because the
Overleaf project must be updated at the same time.

Editing rules
-------------

- Never change BibTeX IDs.  Journal names are written in title case.
- Make minimal changes: no reformatting or unrelated fixes in a commit.
- British spelling (-ise forms, colour, grey, analyse).
- "Target" is the indexed genome; "reference" means a species' canonical
  assembly, as explained in the Methods.
- `\citet{}` when the citation is part of the sentence, `(\cite{})` otherwise,
  several citations separated by semicolons.
- Refer to figures with `\ref`; panel letters are capitals: (A), (B).
- Check statements about the pipeline against its source code (version 3.0.4),
  and statements about LAST against its documentation and source code.
- Prefer few numbers in the text when the figures show them, and plain-language
  qualifications that do not disfavour the compared tools.

Building the PDF locally
------------------------

Overleaf compiles with pdfLaTeX and Biber.  With TeX Live 2023,
`\DocumentMetadata` is not supported: comment it out in a copy of the file.
Then, from the repository root, with `TEXINPUTS=./manuscript//:`,
run `pdflatex`, `biber --input-directory manuscript`, and
`pdflatex` twice.  On Debian, the class needs the packages lmodern,
texlive-latex-extra, texlive-plain-generic, texlive-lang-french,
texlive-fonts-extra and biber.

Use of AI
---------

The Methods section "Use of artificial intelligence" discloses how AI was used.
If your work adds a new kind of contribution, tell the authors so that this
section can be updated.
