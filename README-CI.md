# Project 4

## Project Description

This project walks through how I took the given Angular application and made it run in a Docker container, then set up GH actions for CI so that when things are pushed to the repo, it automatically updates my DH container.

### Tools and their Uses

| Tool    | Use |
| -------- | ------- |
| Docker | Used to containerize and run the Angular Application |
| DockerHub *(DH)* | Stores and hosts the container for easy reuse and deployment |
| GitHub *(GH)* | Hosts the project repo, and handles version control |
| GH Actions | Automates image building and pushing on code changes to DH |

---

### Diagram

![Project 4 Diagram](images/P4_diagram.png)

---

## Part 1

### Docker Setup

I'm on Windows 11, so I used [Docker Desktop](https://www.docker.com/products/docker-desktop/) + WSL2 to get Docker running. 

#### Verifying Docker installed correctly:
```
docker --version
```

#### Testing if a basic container worked:
```
docker run hello-world
```

---

### Running Angular in a container manually

Before touching a Dockerfile, I tested running the Angular app inside a container based on `node:18-bullseye`.

From the project root:

```
docker run -it -v ${PWD}/angular-site:/app -w /app -p 4200:4200 node:18-bullseye /bin/bash
```

Here's what the flags do in the `docker run` command:
- `-it`: runs the container in interactive mode with a terminal
- `-v ${PWD}/angular-site:/app`: mounts my local `angular-site` folder into the container at `/app`
- `-w /app`: sets the pwd inside the container to `/app`
- `-p 4200:4200`: forwards port 4200 from the container to my host machine, so i can access the app

Then inside the container:

```
npm install -g @angular/cli@15.0.3
npm install
ng serve --host 0.0.0.0
```

Note: Angular normally binds to `localhost`, which doesn't work for this.  The `--host 0.0.0.0` makes it accessible outside the container.

#### Checking it worked:
- I validated from the container side by checking the Angular CLI output for the "compiled successfully" message.
- I opened Firefox to http://localhost:4200 and saw the provided birdy website

---

### Dockerfile

After the manual test worked, I built a Dockerfile to automate it.

#### What it does:
```
FROM node:18-bullseye

WORKDIR /app

RUN npm install -g @angular/cli@15.0.3

COPY angular-site/package*.json ./
COPY angular-site/ ./

RUN npm install

EXPOSE 4200

CMD ["ng", "serve", "--host", "0.0.0.0"]
```

In order, this:
- Sets the base image for the container
- Sets the working directory inside the container to `/app`
- Globally installs Angular CLI version 15.0.3 inside the container
- Copies only the `package.json` and `package-lock.json` files from my local `angular-site/` directory into the container's current directory
- Copies all remaining files from `angular-site/` into `/app`
- Installs the app-specific dependencies listed in the `package.json` file
- Tells Docker that the container will listen on port `4200`, which is the default
- Starts the container and binds it to `0.0.0.0` so it can be accessed externally

##### Important: Get Your Directories Together

When I first tried building the image, Docker couldn't find `package.json`. It turned out the `angular-site` folder had another folder inside it,(`wsu-hw-ng-main/`) where the real app files were, so it couldn't find the files.

So I moved everything up one level so `package.json`, `angular.json`, `src/`, etc., were directly inside `angular-site/`.

Once that was done, the `COPY` step in the Dockerfile worked as expected.


#### Building the image:
```
docker build -t angular-bird .
```

#### Running the image:
```
docker run -p 4200:4200 angular-bird
```

#### Verifying it worked:
After building the image, I validated from the container side by checking the container logs and ensuring Angular compiled and served the app without errors.  I also ran a quick check by starting a container from the built image:

```
docker run -it barnum9/barnum-ceg3120 /bin/bash
```

Then inside the container, I ran:

```
curl http://localhost:4200
```

It returned raw HTML, which confirmed that the Angular app was serving correctly inside the container itself.

---

### DH

#### Repo name:
```
barnum9/barnum-ceg3120
```

#### How I created it:
- Logged into DH
- Clicked "Create Repository"
- Named it `barnum-ceg3120`, set it to public

#### Authentication with PAT:
DH requires a Personal Access Token (PAT) instead of a password when authenticating via the Docker CLI.

I logged in through Docker Desktop, which automatically generated a PAT with the necessary scope (read, write, delete).  I did not manually create one, Docker Desktop did that for me.

To verify or manage tokens:

- Go to DH > Security > Personal Access Tokens

- You'll see any active tokens under this menu

- Tokens created by Docker Desktop are listed as Auto-generated

When using the CLI, Docker pulls that saved token automatically for authentication.

#### Pushing my image:
```
docker tag angular-bird barnum9/barnum-ceg3120
docker push barnum9/barnum-ceg3120
```

#### DH Link:
https://hub.docker.com/repository/docker/barnum9/barnum-ceg3120/general

---

## Part 2

### GH Actions and DH

#### Configuring GH repo secrets

To use GH actions with DH and push the image automatically, I created another PAT through my DH account.

##### How to make another PAT in DH
- Go to DH and click your picture in the upper right
- Go to Account Settings > Security > New Access Token
- Give the token a name you can keep track of (I chose GH-ci-token) and set it to all permission scope
- Copy the token down in notepad or something, just so you don't lose it to paste into GH, you can't see this again

##### How to add secrets to GH
- In your repo, go to Settings > Secrets and Variables > Actions (not your user settings, which I originally tried to do lol)
- Click the green "New Repo Secret" button
- Add both secrets from your DH account
    - `DOCKER_USERNAME` is the name I chose to identify the secret of my DH username (`barnum9`)
    - `DOCKER_TOKEN` is the name I chose to identify the PAT I just created, and paste in what I put into Notepad for that secret

These secrets are used instead of your actual credentials, for security.

---

#### Continuous Integration (CI) with GH Actions

##### What the workflow does

This workflow builds and pushes the Angular Docker app from part 1 to DH every time I push to the main branch.  So changes made in my local system, when pushed to GH, would also reflect in DH.

##### Workflow steps, explained

```
name: Project 4

on:
  push:
    branches:
      - main
```
- Triggers the workflow when something is pushed to `main`
```
jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v3
```
- This defines a job called build, and it tells GH to spin up a fresh Ubuntu VM to run the job.  I named the step checkout, because it is telling GH to pull the repo's code into the VM, so the rest of the steps can access it.
```
      - name: Login to DH
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}
```
- This step is named `Login to DH`.  I'm using `docker/login-action@v3` which is a pre-built GH action provided by Docker, and I'm logging in with my secret I put in GH Actions username and password (the PAT).

```
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: barnum9/barnum-ceg3120:latest
```
- This step is named `Build and push` because, well, we're building and pushing.  We're using `docker/build-push-action@v5` as provided by Docker.  The next part has the build context, telling it to use the current directory (the base of the repo) and points to my DockerFile from Part 1.  If we didn't include `push: true` then it would never push it, just build it.  Finally, the tags just are for the name when pushed to DH.

##### What to change if reusing in another repo:

- Update the `tags:` section with the new DH repo name
- Make sure the `context:` and `file:` point to where your Dockerfile is
- Add new secrets if using different credentials

##### [Workflow File](https://github.com/WSU-kduncan/ceg3120-cicd-samanthabarnum/blob/main/.github/workflows/docker.yml)

---

### Testing and Validating

How I tested the workflow:

1. Committed and pushed the `docker.yml` file to my repo in the appropriate folder
2. Checked the Actions tab in GH to watch the workflow run.
3. Fixed errors (like having capital letters in the DH repo name, learned that the hard way)
4. Rinse
5. Repeat

---

#### How I validated it worked

I ran:

```
docker logout
docker login
docker pull barnum9/barnum-ceg3120
docker run -p 4200:4200 barnum9/barnum-ceg3120
```
And then I visited `localhost:4200` in Firefox and saw the app running.

---

## Part 3

I added the diagram at the top of the page for part 3, as well as the resources section below.

#### Resources:

##### Docker Setup and Usage

- [Installing and configuring Docker Desktop on Windows 11](https://docs.docker.com/desktop)
- [Refreshing memory on DH's interface and repo setup](https://docs.docker.com/docker-hub)
- [This served as a guide for understanding how the `-v` flag mounts an Angular app into the docker cntainer](https://docs.docker.com/engine/storage/volumes/)
- [Refreshing memory on foundational understanding of Docker concepts](https://docs.docker.com/get-started)
- [I used this to understand how to write a proper Dockerfile](https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile)
- [Reference to valid commands and syntax for Dockerfiles](https://docs.docker.com/reference/dockerfile/)
- [This clarified the right node image for use in my Dockerfile](https://hub.docker.com/_/node)

##### Docker CLI Commands

- [Used to understand the Docker CLI commands used in my GH Action workflow](https://docs.docker.com/reference/cli/docker/buildx/build/)
- [This helped clarify what `docker run` flags do when testing my image](https://docs.docker.com/reference/cli/docker/container/run/)
- [This was useful when formatting my `docker tag` command, and how to push it to DH via CLI](https://docs.docker.com/reference/cli/docker/image/)


##### Troubleshooting and Stack Overflow

- [I used this to fix a 'no such file or directory' error during Docker build](https://stackoverflow.com/questions/32997269/copying-a-file-in-a-dockerfile-no-such-file-or-directory)
- [This walked me through troubleshooting the weird Angular install failure in Docker (resulting from not having package.json in the right place)](https://stackoverflow.com/questions/49656445/npm-i-running-command-failed-exit-code-254)
- [I followed this to troubleshoot accessing Angular in a container from the host](https://stackoverflow.com/questions/52569990/access-to-localhost-from-other-machine-angular)

##### Docker/Angular Integration

- [I used this to sanity check myself on the process of dockerizing an Angular app](https://dev.to/rodrigokamada/creating-and-running-an-angular-application-in-a-docker-container-40mk)

##### GH Actions and CI/CD

- [This is where I learned how GH Actions works behind the scenes](https://docs.github.com/en/actions/about-github-actions/understanding-github-actions)
- [Used for configuring Docker to build images automatically using GH actions](https://docs.docker.com/build/ci/github-actions)
- [Help with using the Docker/GH Action that builds and pushes images](https://github.com/marketplace/actions/build-and-push-docker-images)
- [Supplementary info for above](https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images)
- [This is what I used to learn about the YML syntax for GH actions workflows](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
- [Learning about how touse encrypted secrets in GH workflows](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions)

##### Angular Docs
- [This article demystified what Angular is and how it works (kinda)](https://v17.angular.io/guide/what-is-angular)
- [Used to find the way to install and use Angular CLI](https://v17.angular.io/cli)

#### Documentation and Diagram Tools
- [Lucidchart](https://www.lucidchart.com/pages)  
- [MD Formatting](https://www.markdownguide.org/)  
- [MD Formatting 2](https://docs.constructor.tech/articles)
- [ChatGPT](https://www.chatgpt.com/)
  - "Can you explain to me how CI/CD works, why it's used, and some irl use cases for it?"
  - "What is different about Angular vs HTML/CSS/JS?  Why would we want to use that instead, for websites that would work either way?"
  - "wtf does code 254 mean when I'm trying to copy an Angular site to a docker container"
    - This is how I found out about package.json not being in a high enough folder for it to find it to deploy
  - "Can you explain to me again, how Docker works?  I have the documentation but my brain is broken."
  - "Can you generate me a template README.md for a project I have?"