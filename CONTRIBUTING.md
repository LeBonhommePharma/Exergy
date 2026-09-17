# CONTRIBUTING

```bash
python3 Exergy/scripts/test_contracts.py
python3 Exergy/scripts/validate-submission.py
# with Swift:
swift test --package-path Exergy/Packages/ExergyCore
swift test --package-path Exergy/Packages/ExergyTheme
```

Conventional commits. Do not put tokens, client secrets, or usage JSON fixtures that look like live keys in the tree.

`SecretPolicy` is load-bearing: CloudKit field names that look like secrets must fail tests.
