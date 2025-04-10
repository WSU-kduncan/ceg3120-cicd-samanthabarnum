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