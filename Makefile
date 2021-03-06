PY=python3
PIP=pip
TEST=pytest

# Override this variable (or any other) by using the --environment option:
#  $ PY_VERSION=3.8 make --environment type-check
PY_VERSION=3.9

PROJECT_NAME=astrometry_net_client

PROJ_FILES=$(PROJECT_NAME)/*.py
TEST_FILES=tests/*.py
EXAMPLE_FILES=examples/*.py
CONFIG_FILES=setup.py 
PY_FILES=$(PROJ_FILES) $(TEST_FILES) $(EXAMPLE_FILES) $(CONFIG_FILES)

# Add the following options for a testresults JUnit like xml report
#-o junit_family=xunit2 --junitxml="testresults.xml"
TEST_ARGS=--cov --cov=$(PROJECT_NAME) --cov-report html -v

BLACK_ARGS=-l 79
ISORT_ARGS=--multi-line=3 --trailing-comma --force-grid-wrap=0 --use-parentheses --line-width=79
FLAKE_ARGS=--docstring-style=numpy --ignore=E203,W503,DAR402

PIP_IGNORE_PKG=--exclude pynvim --exclude astrometry_net_client

default: check-in-venv format lint type-check install ## perform formatting and install

all: default test documentation ## perform all checks, including formatting and testing

check-in-venv:
	env | grep 'VIRTUAL_ENV'

# Packaging
install: dependencies package package-install  ## package and install, with installing dependencies
quick-install: package package-install  ## Repackage and install without reinstalling dependencies

package-install: 
	$(PIP) install dist/$(PROJECT_NAME)-*.tar.gz

package: 
	$(PY) setup.py sdist bdist_wheel

# Uploading
upload-pypi: package
	python3 -m twine upload dist/*

upload-test: package
	python3 -m twine upload --repository testpypi dist/*

# Dependencies for the development environment, 
# e.g. contains Sphinx, flake8, black, isort etc.
dependencies:
	$(PIP) install --upgrade pip setuptools wheel
	$(PIP) install --upgrade -r requirements.txt

# Generate the documentation
documentation:
	make --directory=docs/ html


test: ## Run the default tests (not online & not long)
	$(TEST) $(TEST_ARGS) -m 'not online and not long' tests/

test-long: ## test, also include the tests which are longer (but not online)
	$(TEST) $(TEST_ARGS) -m 'not online' tests/

test-online: ## test, also include the tests which query the online api.
	$(TEST) $(TEST_ARGS) -m 'not long' tests/


test-all: ## test-online, also include the long tests (i.e. uploading files)
	$(TEST) $(TEST_ARGS)  tests/

help: ## Prints help for targets with comments
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

git-pre-push: check-format lint

## Formatting and linting
format: ## Format all the files using black and isort
	black $(BLACK_ARGS) $(PY_FILES)
	isort $(ISORT_ARGS) $(PY_FILES)

check-format:
	black --check $(BLACK_ARGS) $(PY_FILES)
	isort --check-only $(ISORT_ARGS) $(PY_FILES)

lint: ## Check the linting of all files
	flake8 $(FLAKE_ARGS) $(PY_FILES)

type-check: ## Check Type annotations using MyPy
	mypy --python-version=$(PY_VERSION) $(PROJ_FILES) $(TEST_FILES) $(EXAMPLE_FILES)


## Cleanup rules
clean: clean-package clean-docs clean-reports  ## Cleanup

clean-package:
	-rm -r *.egg-info 
	-rm -r build 
	-rm -r dist

clean-docs:
	-make --directory=docs clean

clean-reports:
	-rm -r htmlcov
	-rm .coverage
	-rm testresults.xml

## Misc rules
virt-env:
	python3 -m venv .env

pip-freeze: ## Update requirements.txt and make a backup (for safety) of the current one
	mv requirements.txt requirements.txt.bak
	pip freeze $(PIP_IGNORE_PKG) > requirements.txt
