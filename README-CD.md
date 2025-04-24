# Project 5

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

### Create a New GH Actions Workflow

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
- `uses: docker/metadata-action@v5` use version 5 of the official `docker/metadata-action` from GH marketplace, which automatically breaks down tags with glob patterns
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
- Update any hard-codef repo specific info
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

To confirm that everything worked correctly, I ran the following commands to pull the versioned image from DH and run it locally (once Docker Desktop was actually running, I was too gung ho):

```
docker pull barnum9/barnum-ceg3120:1.0.1
docker run -p 4200:4200 barnum9/barnum-ceg3120:1.0.1
```
and then I visited `localhost:4200` to confirm it's working properly.  The app loaded, confirming the image built from the GH tag was properly pushed to DH, versioned, and still runs as expected.

---

## Part 2

### EC2 Instance Details

#### AMI Information
- AMI: Amazon Linux 2023 AMI
- AMI ID: `ami-0e449927258d45bc4`
- Username for SSH access: `ec2-user`

---

#### Instance Type
- Instance type: `t2.medium`
- 2 CPUs, 4 GB RAM

---

#### HD Size
- 30 GB, gp3 (General Purpose SSD)
- `gp3` provides balanced price and performance for general purpose, including Docker containers.

---

#### Security Group Configuration

| Protocol | Port | Access IPs | Purpose |
|-|-|-|-|
| SSH | 22 | Home IP (`76.243.44.34/32`) | SSH access, restricted to my home IP. |
| HTTP | 80 | `0.0.0.0/0` | Required for external access to the app. |
| HTTPS | 443 | Not enabled | HTTPS is not configured, not within the scope of this project |


> Note:
> SSH access is limited to my home IP to prevent/reduce bad apples.
> HTTP is open to allow everyone to see our birdy app for testing and demos.

---

#### SSH Access

During my first attempt to configure the EC2 instance, the AWS learner account provided a pre-existing key pair named `vockey`.  However, the associated `.pem` was not downloadable.   Without that `pem`, SSH access to the EC2 instance isn't a thing I can do, as AWS does not allow retrieval of private keys after key creation.

To fix this and get SSH access, I created a new key pair through the AWS EC2 dashboard:

- Key pair name: `project5`
- Key pair type: RSA
- Private key file format: `.pem`

The `.pem` file was downloaded upon making the file.  To meet the SSH security requirements, I adjusted the file permissions with:

```
chmod 400 project5.pem
```

This allows AWS to not get mad at me for having too loose of permissions for the `.pem` file, and all new SSH accesses use the command:

```
ssh -i "project5.pem" ec2-user@34.194.10.16
```

This allowed me to gain SSH access for Docker installation and other deployment tasks for the project.

---

### Docker Setup on My EC2 Instance

#### How to Install Docker on Amazon Linux 2023

Once I was connected to my EC2 instance through SSH, I installed Docker with these commands:

```
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user
```

##### What these commands do:

| Command | What it does | Why it's needed |
|-|-|-|
| `sudo dnf update -y` | 	Updates all packages | 	Makes sure I'm not installing Docker on an outdated system |
| `sudo dnf install -y docker` | Installs Docker | Grabs the Docker package and dependencies |
| `sudo systemctl enable docker` | Auto-start Docker at boot | 	Ensures the containers come back after reboot |
| `sudo systemctl start docker` | Starts Docker | Turns Docker on so I can use it immediately |
| `sudo usermod -aG docker ec2-user` | Lets me run Docker without sudo | Saves me from typing `sudo` every time, safer than giving root access |

After that, I had to log out and back in (or reconnect my SSH session) so the permissions would actually take effect and let me use Docker without `sudo`.

> Note: While AWS documentation often shows `yum` for AL2, I'm using `dnf` here because AL 2023 uses `dnf` as the native package manager.

---

#### Dependencies Needed

I didn't need anything extra besides Docker. AL 2023 already had what I needed for this to work as is, so nothing more needed.

---

#### Making Sure Docker was Installed and Working

I checked that Docker was installed with:

```
docker --version
```

Then I tested it by running:

```
docker run hello-world
```

This gave me the little "Hello from Docker!" message, which meant everything was working.

---

### Testing on the EC2 Instance

#### Pulling My Container Image from DH

I pulled my container image down from DH using:

```
docker pull barnum9/barnum-ceg3120:latest
```

I made sure it actually downloaded by checking:

```
docker images
```

> Note: This was the same process I used in my [README-CI](README-CI.md) file.

---

#### Running the Container from the Image

I ran the container with this command:

```bash
docker run -d --name angular-app -p 80:4200 barnum9/barnum-ceg3120:latest
```

This does a few things:
- Runs the container in detached mode (`-d`), so it stays running in the background.
- Names the container `angular-app`, which I'll need later when I automate this process.
- Maps port 4200 inside the container to port 80 on the EC2 instance, so I can actually see it from my browser.

> Note: The Angular app inside the container listens on port 4200, but browsers look for web servers on port 80 by defaul.  Using `-p 80:4200` lets traffic on port 80 from the outside world reach the app running on 4200 inside the container.

---

#### Checking the App was Running

##### Checking from inside the EC2:

```
docker ps
```
This showed me that the `angular-app` container was up and running.

##### Checking from the EC2's public IP:

I copied the EC2's public IP, entered it into a new tab (with http://, not https://), and the Angular app loaded like it was supposed to.

##### Checking from my own computer:

The same as above, I copied the EC2's public IP, entered it into a new tab (with http://, not https://), and the Angular app loaded like it was supposed to.

---

### Scripting the Docker App Refresh

To automate refreshing the container whenever a new image is available on DockerHub, I created a bash script directly on my EC2 instance.  This script stops the currently running container (if it exists), pulls the latest version of my Docker image, and runs a new container with that image.

#### Script Location

The script is saved on the EC2 instance in the `deployment` folder and is named `update.sh`.

---

#### Script Contents

```
#!/bin/bash

CONTAINER_NAME="angular-app"
IMAGE_NAME="barnum9/barnum-ceg3120:latest"

#stop and remove existing container if exists
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

#pull latest
docker pull $IMAGE_NAME

#run new container
docker run -d --name $CONTAINER_NAME -p 80:4200 $IMAGE_NAME
```

---

#### How the Script Works

1. Checks if a container named `angular-app` is currently running:
   - If yes, the script stops and removes it.
   - If no, it just moves on.
2. Pulls the latest image from DH (`barnum9/barnum-ceg3120:latest`).
3. Starts a new container using the freshly pulled image, mapping port 80 on the EC2 instance to port 4200 inside the container.

---

#### Testing the Script

After creating the script with `nano update.sh`, I made it executable with:

```
chmod +x update.sh
```

Then I ran the script manually to test it:

```
./update.sh
```

I verified the container was running with:

```
docker ps
```

Then, I confirmed the app was still loading correctly from the EC2's public IP.

---

### Configuring a Webhook Listener on EC2 Instance

To automate the deployment process when a new Docker image is pushed to DH, I set up a webhook listener on my EC2 instance using [`adnanh/webhook`](https://github.com/adnanh/webhook). This lets my EC2 instance auto-run my `update.sh` script whenever it receives a webhook trigger with the correct secret.

---

#### How I Picked the Webhook Binary

The project asked for `adnanh/webhook`, so I went directly to the [GitHub releases page](https://github.com/adnanh/webhook/releases) for the project.  I downloaded the prebuilt for Linux AMD64 since my EC2 instance is AL 2023 running 64-bit architecture.  This was way simpler than building it from the source in my opinion.

Downloaded and installed with:
```
curl -LO https://github.com/adnanh/webhook/releases/download/2.8.1/webhook-linux-amd64.tar.gz
tar -xvzf webhook-linux-amd64.tar.gz
sudo mv webhook-linux-amd64/webhook /usr/local/bin/
webhook --version  # to confirm the install
```

| Command | What it does | Why it's needed |
|-|-|-|
| `curl -LO https://github.com/adnanh/webhook/releases/download/2.8.1/webhook-linux-amd64.tar.gz` | 	Downloads the precompiled webhook | 	Grabs the right version of the webhook listener for Linux AMD64 so I don't have to build from source |
| `tar -xvzf webhook-linux-amd64.tar.gz` | 	Extracts the downloaded .tar.gz archive | Unpacks the binary so I can move it into my path and use it |
| `sudo mv webhook-linux-amd64/webhook /usr/local/bin/` | 	Moves the webhook binary to a system-wide location (`/usr/local/bin/`) | 	Lets me run `webhook` as a command from anywhere without giving a full path |
| `sudo systemctl start docker` | Starts Docker | Turns Docker on so I can use it immediately |
| `webhook --version` | Checks the installed version of webhook | Confirms that the binary was installed correctly and is ready to use |

---

#### Webhook Hook Definition File

The hook (`hook.json`) definition file lives in my `deployment` folder, and I manually copied it to my EC2 instance using `nano` since I didn't want to clone my whole repo onto the server.

`deployment/hook.json` contents:
```
[
    {
      "id": "refresh-container",
      "execute-command": "/home/ec2-user/deployment/update.sh",
      "command-working-directory": "/home/ec2-user/deployment",
      "trigger-rule": {
        "match": {
          "type": "value",
          "value": "secret",
          "parameter": {
            "source": "header",
            "name": "X-Webhook-Token"
          }
        }
      }
    }
  ]
```

---

### Why I Used `"secret"`

The project asks for a shared secret to make sure the webhook only runs when it's triggered by something legit.  There weren't any specific instructions on how to generate one, so I just kept it simple and used `"secret"` (short, easy to type, does the job).  The token gets passed in the header of the webhook trigger, and the hook definition file checks for it.

Example curl command to trigger:
```
curl -X POST http://34.194.10.16:9000/hooks/refresh-container -H 'X-Webhook-Token: secret'
```

- The The `curl -X POST` part is saying:
  - "I want to send a POST request" (by default, curl sends GET).
- The `-H 'X-Webhook-Token: secret'` is adding a header to the request.
  - That’s how I pass the secret to my webhook.

---

#### Security Group Configuration for Port 9000

When I first tried to trigger the webhook, the request hung because my EC2 instance's security group wasn't allowing inbound traffic on port 9000.  The webhook runs outside of Docker (directly on the EC2 instance), so the Docker `-p` port mapping doesn't apply here.

I fixed this by adding the following inbound rule to my EC2's security group:

- Type: Custom TCP
- Port Range: 9000
- Source: My IP

Without this rule, the webhook listener couldn't receive requests, as it listens by default to porr 9000.

---

#### Testing and Verification

After setting up the hook and opening the security group:

- I started the webhook listener manually:

```
webhook -hooks deployment/hook.json -verbose
```

- Sent the curl request from another WSL instance

- Verified in the webhook logs that the request was received, the token matched, and the `update.sh` script was triggered successfully

Example output:

```
incoming HTTP POST request from 76.243.44.34:64450
refresh-container got matched
refresh-container hook triggered successfully
Pulling from barnum9/barnum-ceg3120
Image is up to date for barnum9/barnum-ceg3120:latest
finished handling refresh-container
```

Confirmed that my container was refreshed and the new image was running using `docker ps` on the EC2.

---

### Testing Webhook Deployment Plan

I still need to run a full test of the end-to-end deployment process. The plan is:

1. Confirm that the webhook listener service is running.

2. Make a small change locally and commit it.

3. Tag the commit and push the tag to trigger the GH Action.

4. Verify that the GH Action builds and pushes the new Docker image to DH.

5. Confirm the webhook on the EC2 instance receives the payload and triggers the refresh script.

6. Check that the container is restarted and running the updated image.

7. Reload the app in the browser to verify the change went live.

Once this test is complete, I’ll update this section to reflect the results.



#### Resources:

https://www.malikbrowne.com/blog/a-beginners-guide-glob-patterns/
https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile
https://docs.docker.com/reference/dockerfile/
https://docs.docker.com/reference/cli/docker/image/
https://docs.docker.com/build/ci/github-actions
https://github.com/marketplace/actions/build-and-push-docker-images
https://aws.amazon.com/ebs/general-purpose/
https://docs.aws.amazon.com/linux/al2023/ug/managing-repos-os-updates.html
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-container-image.html
https://medium.com/@manojkumar_41904/step-by-step-guide-pushing-and-pulling-docker-images-to-aws-elastic-container-registry-ecr-8c02584a76bf
https://cyberpanel.net/blog/dnf-vs-yum
https://askubuntu.com/questions/477551/how-can-i-use-docker-without-sudo
https://docs.docker.com/engine/network/#published-ports
https://askubuntu.com/questions/443789/what-does-chmod-x-filename-do-and-how-do-i-use-it
https://github.com/adnanh/webhook
https://ec.haxx.se/usingcurl/downloads/
https://linuxize.com/post/how-to-extract-unzip-tar-gz-file/
https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html
https://docs.github.com/en/webhooks/webhook-events-and-payloads
https://docs.github.com/en/webhooks
https://docs.github.com/en/webhooks/testing-and-troubleshooting-webhooks/troubleshooting-webhooks
https://api.github.com/meta
https://github.com/docker/for-linux/issues/652
https://github.com/adnanh/webhook/blob/master/docs/Webhook-Parameters.md
https://github.com/adnanh/webhook/blob/master/docs/Hook-Examples.md
