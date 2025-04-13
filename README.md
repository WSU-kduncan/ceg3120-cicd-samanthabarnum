# Project 4
## Part 1

### Project Description

This project walks through how I took a given Angular application and made it run in a Docker container.  Then I built a Docker image for it, pushed that image to DockerHub, and confirmed it works.  It's the foundation for Part 2 and 3.

The app is just a simple demo — the point is learning how to:
- Build a working container manually
- Create a proper Dockerfile
- Push an image to DockerHub
- Document everything so I don’t want to scream later

---

### Docker Setup

I’m on Windows 11, so I used [Docker Desktop](https://www.docker.com/products/docker-desktop/) + WSL2 to get Docker running. 

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

Then inside the container:

```
npm install -g @angular/cli@15.0.3
npm install
ng serve --host 0.0.0.0
```

Note: Angular normally binds to `localhost`, which doesn't work for this.  The `--host 0.0.0.0` makes it accessible outside the container.

#### Checking it worked:
- Angular CLI starts up and says "compiled successfully"
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
- Tells Docker that the container will listen on port `4200`
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
- Same as the manual setup, Angular runs, and I cn view the app at http://localhost:4200

---

### DockerHub

#### Repo name:
```
barnum9/barnum-ceg3120
```

#### How I created it:
- Logged into DockerHub
- Clicked "Create Repository"
- Named it `barnum-ceg3120`, set it to public

#### Authentication with PAT:
DockerHub requires a Personal Access Token (PAT) instead of a password when authenticating via the Docker CLI.

I logged in through Docker Desktop, which automatically generated a PAT with the necessary scope (read, write, delete).  I did not manually create one, Docker Desktop did that for me.

To verify or manage tokens:

- Go to DockerHub > Security > Personal Access Tokens

- You’ll see any active tokens under this menu

- Tokens created by Docker Desktop are listed as Auto-generated

When using the CLI, Docker pulls that saved token automatically for authentication.

#### Pushing my image:
```
docker tag angular-bird barnum9/barnum-ceg3120
docker push barnum9/barnum-ceg3120
```

#### DockerHub Link:
https://hub.docker.com/repository/docker/barnum9/barnum-ceg3120/general

---
## Part 2

### Project Description

Just like in Part 1, I manually tested Angular inside a container, now I'm using automation to build and push that image any time I update the code.

This section explains how I automated the docker imatge build/push process using GitHub (GH) Actions.  I created a PAT, put it in GH, and uploaded a YML file to have it so that when I push to GH, it updates DockerHub (DH).

---

### GH Actions and DH

#### Configuring GH repo secrets

To use GH actions with DH and push the image automatically, I created another PAT through my DH account.

##### How to make another PAT in DH
- Go to DH and click your picture in the upper right
- Go to Account Settings > Security > New Access Token
- Give the token a name you can keep track of (I chose github-ci-token) and set it to all permission scope
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
3. Fixed errors (like having capital letters in the DH repo name)
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

## Part 3 Placeholder