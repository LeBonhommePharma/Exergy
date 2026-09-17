.PHONY: test test-python test-core test-theme

test: test-core test-theme test-python

test-core:
	swift test --package-path Packages/ExergyCore

test-theme:
	swift test --package-path Packages/ExergyTheme

test-python:
	python3 scripts/test_contracts.py
	python3 scripts/validate-submission.py
