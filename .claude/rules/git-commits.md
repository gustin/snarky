# Git Commit Standards

Follow Tim Pope's commit message guide (https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html):

- Subject line: Capitalized, imperative mood, 50 chars or less
- Blank line after subject
- Body: Wrap at 72 chars, explain what and why

## Commit Ownership

Attribute commits to the human developer. The commit history tells the project's story and should reflect human authorship and decision-making.

## Commit Scope

Keep commits focused on what was accomplished. The commit message captures a completed unit of work, not a roadmap. Future work belongs in issues or planning docs.

**No "and" in commit subjects.** If the subject needs "and", it is two commits. Each commit captures one idea.

## Capture commits

Some commits deliver a reference artifact rather than a behavior change: baselines, fixtures, ratings, snapshots, design tokens, voice samples, generated illustrations, benchmark results, curated datasets. The "what can users now do?" question doesn't apply the same way. The capability delivered is the artifact's availability and what it represents.

Acceptable subject verbs: `Baseline`, `Record`, `Capture`, `Curate`, `Snapshot`, `Import`, `Collect`.

The body describes what the artifact represents (construct, scope, purpose) without citing counts, metrics, latency, or the run that produced it.

Distinguish from behavior commits: if the commit changes how the system works, not what reference data it holds, use behavior-commit framing instead.

Omit process from commit messages: no review tool names (Codex, Copilot, etc.), no "from X review," no round counts. The commit describes what changed and why, not how it got there.

Omit process metrics from commit bodies: line counts, file counts, test counts, number of review rounds. These are build artifacts, not narrative. Describe what the work does and why, not how big it is.

Omit implementation details from commit bodies: no file paths (describe by role), no variable names, no constant names, no internal code references. The reader has `git show` for the code; the body explains what changed and why in plain language.

## Self-contained narrative

A commit message describes the state of the system after the commit lands. Do not rely on the reader having context for what came before or what comes after.

**Don't:**
- Do not use continuity words: "still," "now," "no longer," "continues to," "used to," "previously." These assume the reader knows prior state.
- Do not frame as before/after contrast ("was X, now Y"). State what the code does.
- Do not preview or reference future commits ("Step 3 will..." or "later we'll..."). This commit stands alone.
- Do not narrate the change ("moved X from A to B"). Describe where X lives and why that location is correct.
- Do not narrate documentation or plan updates ("the plan is reconciled," "the technique doc is updated," "documentation now records X," "the plan reflects Y"). If a plan or doc edit rides along with a code change, frame the edit as the capability or decision the document now carries, not as the meta-action of updating.

A reader pulling this commit from `git log` months from now has no conversation context. Write for them.

## Approval Gates

Stage files and create commits only when explicitly requested. Push to remote only when explicitly approved. Trunk-based development means each commit is a deliberate narrative point.

**Don't:**
- Do not stage files or run `git commit` after proposing a message. A proposed message is not approval. Wait for explicit "commit" or "go ahead."
- Do not add a Co-Authored-By tag or any attribution to Claude. The commit belongs to the developer.
- Do not include counts in commit bodies ("73 phrases," "220 fixtures"). Describe what, not how many.
- Do not put implementation vendors, provider names, model names, subscription names, or tool invocations in commits where the capability delivered is something else.

## Commit Message Guidelines

**Frame technical changes in terms of user value:**
- Lead with what the change enables for users
- Include technical details but emphasize the product impact
- Think "what can users now do?" not just "what code changed"

**Strip the implementation before writing the subject.** Every commit has some plumbing involved. The subject should not name it. Before writing, ask: if the reader knows nothing about the framework, the provider, the library, the tool, the script, the survey, or the internal module, does the subject still describe what the system can now do?

**Don't:**
- Do not use "Add" for every commit. Rotate verbs: Introduce, Wire, Parse, Extract, Score, Model, Track, Render, Stream.
- Do not use "Improve" or "Update" as the subject verb when a more specific verb exists.
- Do not frame the subject around implementation ("Create migration for X"). Frame it around capability.
