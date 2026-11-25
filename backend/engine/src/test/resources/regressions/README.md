# Regression corpus (LE-010)

Every `*.txt` file here is replayed by `engine.model.RegressionCorpusTest` through both the engine's `OrderBook`
and the naive `engine.ref.ReferenceBook`; after every line the ids, cancel results, trades and full depth must be
equal. Unlike a failing seed, a file here does not change when `ActionGen` changes.

Format: one action per line, the REPL grammar (`make repl`):

    buy 5@100      # limit order: qty@price
    sell 3         # market order
    cancel 2       # id of an order still resting at this line
    book           # no-op (a cancel with nothing resting)

Lines starting with `#` and blank lines are comments. Ids start at 1 and every submit takes the next one, so
`cancel 2` means the second order submitted. Strip comment lines before pasting a file into the REPL.

Adding a case: when a differential test fails, shrink the failing actions and save the result here:

    Shrinker.regressionFile(ActionGen.generate(seed, 1_000))   // → file text, 1-minimal

Name the file after what it pins down (`time-priority.txt`), add a `#` line saying why, then fix the engine.
