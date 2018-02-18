######################################################################
# Thanks:
#   https://github.com/aktau/github-release
#   https://github.com/boertel/bump
#   https://github.com/MozillaSecurity/dolly
#   https://gist.github.com/danielestevez/2044589
#   https://github.com/vaab/gitchangelog
#   https://github.com/tj/git-extras (not implemented yet because not
#       know to generate release changfelog like github-release)
######################################################################

# Sane checks
ifeq ($(GITHUB_TOKEN),)
  $(error GITHUB_TOKEN is not set)
endif

######################################################################
# Constants
######################################################################

LAST_TAG := $(shell git describe --abbrev=0 --tags)
COMPARISON := "$(LAST_TAG)..HEAD"

CUR_VER=$(shell git describe --abbrev=0 --tags)
CUR_TAG=$(shell git describe --abbrev=0 --tags)
NUM_TAGS=$(shell git tag | wc -l)
IS_GITDIR=$(shell git rev-parse --is-inside-work-tree)
NEXT_PATCH=$(shell tools/bump patch `git describe --tags --abbrev=0`)
NEXT_MINOR=$(shell tools/bump minor `git describe --tags --abbrev=0`)
NEXT_MAJOR=$(shell tools/bump major `git describe --tags --abbrev=0`)
DIST_SRC=$(shell ls src/)

.PHONY: clean-pyc clean-build clean guard-%

help:
	@echo "build-zip     - build ZIP files to be dsitributed in the github release."
	@echo "build-dist    - put files under build/ into dist/."
	@echo "docker-up-dev         - Run docker-compose -f docker-compose-dev.yml up -d."
	@echo "docker-down-dev       - Run docker-compose -f docker-compose-dev.yml down."
	@echo "docker-build-dev      - build Docker dev image."
	@echo "docker-build          - build Docker latest image."
	@echo "docker-clean-dev      - clean Docker dev image."
	@echo "docker-clean          - clean Docker latest image."
	@echo "docker-clean-dangling - clean all Docker dangling images."
	@echo "check-status          - will check whether there are outstanding changes."
	@echo "check-release         - will check whether the current directory matches the tagged release in git."
	@echo "patch-release         - increments the patch release level, build and push to github."
	@echo "minor-release         - increments the minor release level, build and push to github."
	@echo "major-release         - increments the major release level, build and push to github."
	@echo "clean                 - remove all build artifacts"
	@echo "clean-build           - remove build artifacts"
	@echo "clean-pyc             - remove Python file artifacts"
	@echo "showver               - will show the current release tag based on the directory content."
	@echo "install-tools         - install tools needed to manage the project"

rootfs-fixperms:
	-@chmod -R go-w src/standalone

docker-down-dev:
	docker-compose -f src/docker/docker-compose-dev.yml down

docker-up-dev:
	docker-compose -f src/docker/docker-compose-dev.yml up -d

docker-clean-dangling:
	docker ps -a -f status=exited -q  | xargs -r docker rm -v
	docker images --no-trunc -q -f dangling=true | xargs -r docker rmi

docker-clean-dev:
	-@docker rmi daspanel/runtime-static:dev

docker-clean:
	-@docker rmi daspanel/runtime-static:latest

docker-build-dev: clean docker-clean-dev rootfs-fixperms
	docker build -f src/docker/Dockerfile.dev -t daspanel/runtime-static:dev src/docker

docker-build: clean docker-clean rootfs-fixperms
	docker build -f src/docker/Dockerfile -t daspanel/runtime-static:latest src/docker

install-tools:
	sudo pip install gitchangelog pystache
	wget https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 -O github-release.tar.bz2
	tar xvjf github-release.tar.bz2 --strip-components 3 -C tools/
	rm github-release.tar.bz2
	chmod ugo+x tools/github-release
	wget https://raw.githubusercontent.com/boertel/bump/master/bump -O tools/bump
	chmod ugo+x tools/bump

# Verify if env variable passe as argument is defined
guard-%: GUARD
	@ if [ -z '${${*}}' ]; then echo 'Environment variable $* not set.' && exit 1; fi

.PHONY: GUARD
GUARD:

patch-release: guard-GITHUB_TOKEN clean check-status check-release build-zip build-dist
	echo "Patch release $(NEXT_PATCH)..."
	@git tag -a "$(NEXT_PATCH)" -m "Patch release $(NEXT_PATCH)"
	@gitchangelog > ./CHANGELOG.md
	@git tag -d "$(NEXT_PATCH)"
	@git add CHANGELOG.md
	@git commit -am "CHANGELOG.md for $(NEXT_PATCH) generated !cosmetic"
	@git tag -a "$(NEXT_PATCH)" -m "Patch release $(NEXT_PATCH)"
	@git push
	@git push --tags
	@changelog=$$(git log $(COMPARISON) --oneline --no-merges) ; \
	echo "**Changelog $(NEXT_PATCH)**<br/>$$changelog"; \
	tools/github-release release -u daspanel -r runtime-static -t $(NEXT_PATCH) -n $(NEXT_PATCH) -d "**Changelog**<br/>$$changelog"
	@DIST_FILES="$(shell ls dist/)"; \
	echo "$$DIST_FILES"; \
	for i in $$DIST_FILES; \
	do \
		echo "Uploading $$i..."; \
		tools/github-release upload -u daspanel -r runtime-static -t $(NEXT_PATCH) -n $$i -f dist/$$i -R; \
	done

minor-release: guard-GITHUB_TOKEN clean check-status check-release build-zip build-dist
	echo "Minor release $(NEXT_MINOR)..."
	@git tag -a "$(NEXT_MINOR)" -m "Minor release $(NEXT_MINOR)"
	@gitchangelog > ./CHANGELOG.md
	@git tag -d "$(NEXT_MINOR)"
	@git add CHANGELOG.md
	@git commit -am "CHANGELOG.md for $(NEXT_MINOR) generated !cosmetic"
	@git tag -a "$(NEXT_MINOR)" -m "Minor release $(NEXT_MINOR)"
	@git push
	@git push --tags
	echo $(COMPARISON)
	@changelog=$$(git log $(COMPARISON) --oneline --no-merges) ; \
	echo "**Changelog $(NEXT_MINOR)**<br/>$$changelog"; \
	tools/github-release release -u daspanel -r runtime-static -t $(NEXT_MINOR) -n $(NEXT_MINOR) -d "**Changelog**<br/>$$changelog"
	@DIST_FILES="$(shell ls dist/)"; \
	echo "$$DIST_FILES"; \
	for i in $$DIST_FILES; \
	do \
		echo "Uploading $$i..."; \
		tools/github-release upload -u daspanel -r runtime-static -t $(NEXT_MINOR) -n $$i -f dist/$$i -R; \
	done

major-release: guard-GITHUB_TOKEN clean check-status check-release build-zip build-dist
	echo "Major release $(NEXT_MAJOR)..."
	@git tag -a "$(NEXT_MAJOR)" -m "Major release $(NEXT_MAJOR)"
	@gitchangelog > ./CHANGELOG.md
	@git tag -d "$(NEXT_MAJOR)"
	@git add CHANGELOG.md
	@git commit -am "CHANGELOG.md for $(NEXT_MAJOR) generated !cosmetic"
	@git tag -a "$(NEXT_MAJOR)" -m "Major release $(NEXT_MAJOR)"
	@git push
	@git push --tags
	@changelog=$$(git log $(COMPARISON) --oneline --no-merges) ; \
	echo "**Changelog $(NEXT_MAJOR)**<br/>$$changelog"; \
	tools/github-release release -u daspanel -r runtime-static -t $(NEXT_MAJOR) -n $(NEXT_MAJOR) -d "**Changelog**<br/>$$changelog"
	@DIST_FILES="$(shell ls dist/)"; \
	echo "$$DIST_FILES"; \
	for i in $$DIST_FILES; \
	do \
		echo "Uploading $$i..."; \
		tools/github-release upload -u daspanel -r runtime-static -t $(NEXT_MAJOR) -n $$i -f dist/$$i -R; \
	done


showver:
	@echo $(CUR_TAG)

build-zip:
	-@mkdir -p build
	@rm -rf build/*.zip
	@for i in $(DIST_SRC); \
	do \
		cd src/$$i; \
		zip -q -r ../../build/$$i.zip *; \
		cd ../..; \
	done

build-dist:
	-@mkdir -p dist
	@rm -rf dist/*
	@BUILD_SRC="$(shell ls build/)"; \
	echo "$$BUILD_SRC"; \
	for i in $$BUILD_SRC; \
	do \
		cp build/$$i dist/$$i; \
	done

check-status:
	@if [ `git status -s . | wc -l` != 0 ] ; then echo "\n\n\n\n\tERROR: YOU HAVE UNCOMMITTED CHANGES\n\n  Commit any pending changes before push new release.\n\n\n\n"; exit 1; fi

check-release:
	@echo "LAST_TAG=$(LAST_TAG), Current TAG $(CUR_TAG), RELEASE $(CUR_VER) - $(NUM_TAGS) - $(IS_GITDIR)"
	@if [ $(IS_GITDIR) != true ] ; then echo "\n\n\n\n\tERROR: YOU DON'T HAVE CREATED A GIT PROJECT\n\n  Create and initialize a git project before continue.\n\n\n\n"; exit 1; fi
	@if [ $(NUM_TAGS) = 0 ] ; then echo "\n\n\n\n\tERROR: YOU NOT HAVE CREATED ANY GIT TAG\n\n  Commit any pending changes and create new tag/release using:\n\n\t'make [minor,major,patch]-release'.\n\n\n\n"; exit 1; fi
	@echo "*** OK to push release ***"

clean: clean-build clean-pyc
	find . -name '*~' -exec rm -f {} +

clean-build:
	rm -rf build/*
	rm -rf dist/*
	rm -rf .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc:
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +
	find . -name '*~' -exec rm -f {} +



