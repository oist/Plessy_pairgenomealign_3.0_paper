Prompts for AI agents
=====================

Two prompts to compare the plans that AI agents write for a whole-genome
alignment pipeline with the design choices of nf-core/pairgenomealign.  The
results are summarised in the Methods of the article, section "Use of artificial
intelligence", and in `summary.md`.

- `prompt_A.txt`: a short request, as a user might type it.
- `prompt_B.txt`: a detailed request that states the uses the pipeline was built
  for, with generic headings that do not hint at its design.
- `runs.tsv`: one line per answer (agent, model and version, date, settings).
- `prompt_A/`, `prompt_B/`: the answers, one text file per agent.
- `summary.md`: the answers scored against the checklist below.

Procedure
---------

- Paste each prompt unchanged, in a new conversation, two or three times per
  agent, because answers vary between runs.
- Turn web search off where possible: the pipeline documentation and this
  repository, including this directory, are public.  Use an account without
  memory or project context related to this work.
- Save each full answer in `prompt_A/` or `prompt_B/` and fill a line of
  `runs.tsv`, including whether the answer names nf-core/pairgenomealign.

Checklist
---------

Fixed before reading any answer, from the design choices listed in the
Discussion of the article.  For each answer, note whether it proposes:

1. a reduction of the alignments to one-to-one relationships, or an
   equivalent such as chaining and netting;
2. training of substitution and gap scores for each pair of genomes;
3. masking of tandem repeats;
4. an indexed output combining many genomes that genome browsers display;
5. a solution to the CIGAR length limit of BAM/CRAM for long chromosomes;
6. contig or scaffold boundaries on the dot plots;
7. a report summarising all the pairs;
8. substitution statistics for each pair;
9. tests on full-size genomes;
10. handling of assemblies with millions of scaffolds.

Also note what an answer proposes that the pipeline lacks.  For an unbiased
reading, answers can be anonymised and scored by someone who did not run them.
