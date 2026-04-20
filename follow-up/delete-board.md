Best follow-up (later, not blocking this commit):
1. Add an atomic repo operation for delete-if-empty (or optimistic lock via boardVersion).
2. Keep service as policy owner, but have repo enforce the atomic precondition at persistence boundary.
3. Add a concurrency test around delete-vs-create-todo conflict behavior.