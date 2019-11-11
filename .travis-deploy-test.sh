#!/bin/sh

# Immediately cancel if there is no deployment key
if [ -z "${STUDIO_TEST_DEPLOY_KEY}" ]; then
  echo No deployment key. Canceling deployment.
  exit 0
fi

set -eu

# Prepare GitHub SSH key
if [ "${TRAVIS_PULL_REQUEST:-false}" = "false" ]; then
  srcbranch="${TRAVIS_BRANCH}"
else
  srcbranch="pull-request-${TRAVIS_PULL_REQUEST}"
fi
echo "${STUDIO_TEST_DEPLOY_KEY}" | base64 -d > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-keyscan github.com >> ~/.ssh/known_hosts

set -x

srcpath="$(pwd)"
deploydir="build-${TRAVIS_REPO_SLUG}-${TRAVIS_BUILD_NUMBER}-${srcbranch}"
deploydir="$(echo "${deploydir}" | sed 's/[^a-Z0-9]/-/g')"
export PUBLIC_URL="/${deploydir}"
npm ci
npm run build

# Get target repository
cd
rm -rf studio-test || :
git clone "git@github.com:elan-ev/studio-test.git"
cd studio-test
git checkout gh-pages

# Add new content
mv "${srcpath}/build/" "${deploydir}"

# Build new index
echo '<html><body><ul>' > index.html
find . -maxdepth 1 -name 'build*' -type d \
  | sort \
  | sed 's/^\(.*\)$/<li><a href=\1>\1<\/a><\/li>/' >> index.html
echo '</ul></body></html>' >> index.html

git add ./*
commit="$(cd "${srcpath}" && git log --oneline --no-decorate -n1 "${TRAVIS_COMMIT}")"
git commit -m "Build #${TRAVIS_BUILD_NUMBER} ($(date)) | ${commit}"
git push origin gh-pages
