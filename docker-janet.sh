#!/bin/bash

DOCKER_REPO=leafgarland

LAST_COMMIT=$(<last_commit.txt)
CURRENT_COMMIT=$(curl -L -s -H 'Accept: application/json' https://api.github.com/repos/janet-lang/janet/branches/master | jq -j .commit.sha)

REVISION="$CURRENT_COMMIT"
DATE=$(date '+%Y-%m-%dT%H:%M:%S')

function docker-build () {
    TAGNAME=$1
    COMMIT=$2
    echo "Building with TAGNAME=$TAGNAME and COMMIT=$COMMIT"

    docker build . --target=core --tag $DOCKER_REPO/janet:$TAGNAME \
        --build-arg "COMMIT=$COMMIT" \
        --label "org.opencontainers.image.revision=$COMMIT" \
        --label "org.opencontainers.image.created=$DATE" \
        --label "org.opencontainers.image.source=https://github.com/janet-lang/janet"
    docker build . --target=dev --tag $DOCKER_REPO/janet-sdk:$TAGNAME \
        --build-arg "COMMIT=$COMMIT" \
        --label "org.opencontainers.image.revision=$COMMIT" \
        --label "org.opencontainers.image.created=$DATE" \
        --label "org.opencontainers.image.source=https://github.com/janet-lang/janet"
}

if [ "$LAST_COMMIT" == "$CURRENT_COMMIT" ]; then
    echo "No new commits since $CURRENT_COMMIT"
    exit 0
fi

echo "Building image for latest commit $CURRENT_COMMIT, last commit was $LAST_COMMIT"
docker-build latest $CURRENT_COMMIT

LAST_TAG=$(<last_tag.txt)
CURRENT_TAG=$(curl -L -s -H 'Accept: application/json' https://api.github.com/repos/janet-lang/janet/tags | jq -j .[0].name)

if [ "$LAST_TAG" == "$CURRENT_TAG" ]; then
    echo "No new tags since $CURRENT_TAG"
    exit 0
fi

CURRENT_TAG_COMMIT=$(curl -L -s -H 'Accept: application/json' https://api.github.com/repos/janet-lang/janet/tags | jq -j .[0].commit.sha)

if [ "$CURRENT_TAG_COMIT" == "$CURRENT_COMMIT" ]; then
    echo "Tagging image for latest tag $CURRENT_TAG, last tag was $LAST_TAG"
    docker tag $DOCKER_REPO/janet:latest $DOCKER_REPO/janet:$CURRENT_TAG
    docker tag $DOCKER_REPO/janet-sdk:latest $DOCKER_REPO/janet-sdk:$CURRENT_TAG
else
    echo "Building new image for $CURRENT_TAG at commit $CURRENT_TAG_COMMIT"
    docker-build $CURRENT_TAG $CURRENT_TAG_COMMIT
fi

echo $DOCKER_PASSWORD | docker login -u leafgarland --password-stdin
docker push $DOCKER_REPO/janet
docker push $DOCKER_REPO/janet-sdk

echo $CURRENT_COMMIT > last_commit.txt
echo $CURRENT_TAG > last_tag.txt


if ! git diff --no-ext-diff --quiet --exit-code; then
    git add -A && git commit -m 'Update last_commit' --allow-empty && git push -u origin master
fi
