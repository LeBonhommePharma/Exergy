.PHONY: test test-python test-core test-theme icons

test: test-core test-theme test-python

icons:
	python3 scripts/render_app_icons.py

test-core:
	swift test --package-path Packages/ExergyCore

test-theme:
	swift test --package-path Packages/ExergyTheme

test-python:
	python3 scripts/test_contracts.py
	python3 scripts/validate-submission.py
