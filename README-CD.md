# Project 4

## Project Description

## Part 1

### View Existing Git Tags
To see all tags in your local repo:

```
git tag
```

And to see remote tags:
```
git ls-remote --tags origin
```

### Create a Git Tag Using Semantic Versioning

```
git tag -a v1.0.0 -m "1st release"
git push origin v1.0.0
```

This tagged my current push with v1.0.0, and commented it saying it was my first release.

### Create a New GitHub Actions Workflow

I wanted to keep my old file for reference, so I commented out the trigger and renamed the old file, and made a new one.

#### What the Workflow Does

This workflow runs only when a git tag is pushed that matches the semantic versioning format `vX.X.X`. When triggered, it:
- Extracts version metadata from the tag
- Logs in to DH using secrets
- Builds a docker image from my Dockerfile
- Tags the image with multiple versions (major, minor, patch, and `latest`)
- Pushes all of those tags to DH

Here's the full contents of my docker.yml workflow file for Project 5

```
name: Project 5

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: barnum9/barnum-ceg3120
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=raw,value=latest

      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
```

- `on: push:` when something is pushed to the repo
- `tags:` but not just any push, only when the thing being pushed is a tag that matches this pattern
- `- 'v*.*.*'` a glob pattern such as `v1.0.0` or `v4.2.0`
- `runs-on: ubuntu-latest` make me a brand new ubuntu vm for this job to run in
- `id: meta` just lets future steps reference the output of this step
- `uses: docker/metadata-action@v5` use version 5 of the official `docker/metadata-action` from github marketplace, which automatically breaks down tags with glob patterns
- `with:` lets me introduce parameters given to the `docker/metadata-action`
- `images: barnum9/barnum-ceg3120` This is my DH image name.  Every generated tag will be applied to this image.
- `type=semver,pattern={{version}}` Take the full semantic version number and use it as a tag, ie `barnum9/barnum-ceg3120:1.2.3`
- `type=semver,pattern={{major}}.{{minor}}` This creates a minor version tag ie `barnum9/barnum-ceg3120:1.2`
- `type=semver,pattern={{major}}` This creates a major version tag ie `barnum9/barnum-ceg3120:1`
- `type=raw,value=latest` Also tag the image as `latest` every time ie `barnum9/barnum-ceg3120:latest`
- `tags: ${{ steps.meta.outputs.tags }}` This accesses the output from where I named `meta` earlier, and then 'use all the tags generated in the extract metadata step.'

### Reusing This Workflow in Another Repo

- Update the `images:` value to your new/correct DH repo name
- Make sure your Dockerfile path (`file:`) is correct
- Update any hard-coded repo specific info
- Add DH secrets to the new repo (`DOCKER_USERNAME`, `DOCKER_TOKEN`)

### Testing and Validating

To test that the workflow works as expected, I:

1. Made sure my Dockerfile is working and builds locally

2. Created a version tag:

```
git tag -a v1.0.1 -m "next patch"
git push origin v1.0.1
```

3. Went to the actions tab on GH and watched the workflow run

4. After it completed, I checked DH to confirm that 4 tags were pushed:

- `latest`
- `1`
- `1.0`
- `1.0.1`

To confirm that everything worked correctly, I ran the following commands to pull the versioned image from DockerHub and run it locally (once Docker Desktop was actually running, I was too gung ho):

```
docker pull barnum9/barnum-ceg3120:1.0.1
docker run -p 4200:4200 barnum9/barnum-ceg3120:1.0.1
```
and then I visited `localhost:4200` to confirm it’s working properly.  The app loaded, confirming the image built from the GH tag was properly pushed to DH, versioned, and still runs as expected.


#### Resources:

https://www.malikbrowne.com/blog/a-beginners-guide-glob-patterns/
https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile
https://docs.docker.com/reference/dockerfile/
https://docs.docker.com/reference/cli/docker/image/
https://docs.docker.com/build/ci/github-actions
https://github.com/marketplace/actions/build-and-push-docker-images
