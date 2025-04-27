# Project 5

## Project Description

This project implements a CD workflow using GitHub webhooks and an AWS EC2 instance running a Dockerized Angular app.  The deployment process is triggered automatically when a new version tag is pushed to the GH repo.  A webhook listener running on the EC2 instance receives the payload from GH, verifies it, pulls the latest DH image, and redeploys the container.  This makes sure that the EC2 instance is updated automatically on every tagged release.

This project builds on the containerization work from Project 4 and adds CD on top of it.  The goal was to automatically redeploy my Angular app running on an EC2 instance whenever I push a new version tag to GH.

### CD Overview Diagram

The following diagram shows the CD workflow for this project.  It shows how code changes, tagging, GH Actions, DH, and the EC2 instance interact to automate deployment.

![Diagram](/images/diagram.png)

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

> This helps confirm whether your local and remote tags match

### Create a Git Tag Using Semantic Versioning

I used semantic versioning for my tags since that's what triggers the deployment process for this projec.  Here's how to create a new tag and push it to GH:

```
git tag -a v1.0.0 -m "1st release"
git push origin v1.0.0
```

This tagged my current push with v1.0.0, and commented it saying it was my first release.

The `-a` flag makes the tag annotated, and -m is where you put your note about what this tag is.

As soon as the tag is pushed, it triggers the GH Action workflow and kicks off the deployment process on my EC2 instance.


### Create a New GH Actions Workflow

I kept my original GH Actions workflow file for reference, I just renamed it and commented out the trigger.
For this deployment, I created a new workflow that triggers only when a tag is pushed, since that's what the rubric called for.

#### What the Workflow Does

This workflow runs only when a git tag is pushed that matches the semantic versioning format `vX.X.X`. When triggered, it:
- Extracts version metadata from the tag
- Logs in to DH using my repo secrets
- Builds a docker image from my Dockerfile
- Tags the image with multiple versions (major, minor, patch, and `latest`)
- Pushes all of those tags to DH

Here's the full contents of my [docker.yml](.github/workflows/docker.yml) workflow file for Project 5

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

      - name: Extract metadata
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

- `on: push:` the workflow listens for pushes to the repo
- `tags:` but not just any push, only when the thing being pushed is a tag that matches this pattern
- `- 'v*.*.*'` a glob pattern such as `v0.0` or `v4.2.0`
- `- 'v*.*.*'` a glob pattern such as `v0.0` or `v4.2.0`
- `runs-on: ubuntu-latest` make me a brand new ubuntu VM for this job to run in
- `id: meta` just lets future steps reference the output of this step
- `uses: docker/metadata-action@v5` use version 5 of the official `docker/metadata-action` from GH marketplace, which automatically breaks down tags with glob patterns
- `with:` lets me introduce parameters given to the `docker/metadata-action`
- `images: barnum9/barnum-ceg3120` This is my DH image name.  Every generated tag will be applied to this image.
- `type=semver,pattern={{version}}` Take the full semantic version number and use it as a tag, ie `barnum9/barnum-ceg3120:2.3`
- `type=semver,pattern={{major}}.{{minor}}` This creates a minor version tag ie `barnum9/barnum-ceg3120:2`
- `type=semver,pattern={{version}}` Take the full semantic version number and use it as a tag, ie `barnum9/barnum-ceg3120:2.3`
- `type=semver,pattern={{major}}.{{minor}}` This creates a minor version tag ie `barnum9/barnum-ceg3120:2`
- `type=semver,pattern={{major}}` This creates a major version tag ie `barnum9/barnum-ceg3120:1`
- `type=raw,value=latest` Also tag the image as `latest` every time ie `barnum9/barnum-ceg3120:latest`
- `tags: ${{ steps.meta.outputs.tags }}` Grabs the generated tags from the earlier metadata step and uses them here for the docker build and push.

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

##### Allowing GH Webhook Payloads on Port 9000

The webhook listener on the EC2 instance listens on port 9000, outside of docker (directly on the EC2 instance itself).  This means Docker's `-p` port mapping does not apply here, since webhook isn't containerized.

In order for the webhook listener on the EC2 instance to receive payloads from GH, I needed to allow inbound traffic on port 9000 from GH's webhook delivery IP ranged, which can be found [here](https://api.github.com/meta).

> Heads up:
These IP addresses change every so often, so if things break, make sure the IPs in that link under `hooks` match your security group.

I added these inbound rules based on their list.

| Protocol | Port | GH IP for Webhooks |
|-|-|-|
| TCP | 9000 | 192.30.252.0/22 |
| TCP | 9000 | 140.82.112.0/20 |
| TCP | 9000 | 185.199.108.0/22 |
| TCP | 9000 | 143.55.64.0/20 |

> Note:
During testing, I temporarily allowed port 9000 from my own home IP to verify that the webhook listener was working properly before I added GH's ranges.

#### EIP Configuration

The AWS learner lab environment gives EC2 instances a dynamic public IP that changes every time the lab is stopped and started.  This broke my deployment workflow, requiring me to update my webhook, and was a giant pain every time AWS learner lab stopped my instance.

To solve this, I attached an EIP to the EC2 instance, which provides a static public IP address that remains consistent across lab sessions, even if the instance stops and starts again.

- EIP given: `34.194.10.16`

> Note:
After assigning the EIP, I updated the webhook one last time to use the EIP, in order to keep my deployment workflow stable across reboots.

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

> Also note: you *have* to restart, or log out and log back in, or *something* to have docker recognize `ec2-user` as part if the docker group.

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

##### Checking from the EC2's EIP:

I copied the EC2's EIP, entered it into a new tab (with http://, not https://), and the Angular app loaded like it was supposed to.

##### Checking from my own computer:

The same as above, I copied the EC2's EIP, entered it into a new tab (with http://, not https://), and the Angular app loaded like it was supposed to.

---

### Scripting the Docker App Refresh

To automate refreshing the container whenever a new image is available on DH, I created a bash script directly on my EC2 instance.  This script stops any currently running container (if it exists) with the name `angular-app`, pulls the latest version of my docker image, and runs a new container with that image.

#### Script Location

The script is saved on the EC2 instance in the `deployment` folder and is named [`update.sh`](deployment/update.sh).

---

#### Script Contents

```
#!/bin/bash

CONTAINER_NAME="angular-app"
IMAGE_NAME="barnum9/barnum-ceg3120:latest"

# get container id matching the container name, whether running or exited
CONTAINER_ID=$(docker ps -aq -f name=$CONTAINER_NAME)

# if container exists, stop and remove them
if [ ! -z "$CONTAINER_ID" ]; then
    docker ps -a -f name=$CONTAINER_NAME
    docker rm -f $CONTAINER_ID
else
    echo "none here"
fi

docker pull $IMAGE_NAME

docker run -d --restart unless-stopped --name $CONTAINER_NAME -p 80:4200 $IMAGE_NAME
```

---

#### How the Script Works

1. Finds containers named `angular-app`:
    - Uses `CONTAINER_ID=$(docker ps -aq -f name=$CONTAINER_NAME)` to get *all* container IDs that match that name, running or stopped.
      - `docker ps` lists containers.
       - `-a`: includes both running and stopped containers.
      - `-q`: this makes the output not be a giant mess.
      - `-f name=$CONTAINER_NAME`: lets you narrow down the list to just the containers with the name `angular-app`.
    - Uses `CONTAINER_ID=$(docker ps -aq -f name=$CONTAINER_NAME)` to get *all* container IDs that match that name, running or stopped.
      - `docker ps` lists containers.
       - `-a`: includes both running and stopped containers.
      - `-q`: this makes the output not be a giant mess.
      - `-f name=$CONTAINER_NAME`: lets you narrow down the list to just the containers with the name `angular-app`.
2. If a container exists:
    - It prints out the matching containers with `docker ps -a -f name=$CONTAINER_NAME`.
    - Then forcefully removes the container(s) with `docker rm -f $CONTAINER_ID`.
      - Removes the container named `angular-app`, whether running or not.
      - Forces it to stop if it's still running, so I don't have to stop it manually first.
      - Clears the way so the script can pull the new image and create a fresh container without naming drama.
    - It prints out the matching containers with `docker ps -a -f name=$CONTAINER_NAME`.
    - Then forcefully removes the container(s) with `docker rm -f $CONTAINER_ID`.
      - Removes the container named `angular-app`, whether running or not.
      - Forces it to stop if it's still running, so I don't have to stop it manually first.
      - Clears the way so the script can pull the new image and create a fresh container without naming drama.
3. If no container exists:
    - It just prints `none here` and continues on, I had that for debugging purposes.
    - It just prints `none here` and continues on, I had that for debugging purposes.
4. Pulls the latest image from DH:
    - Grabs the newest copy of `barnum9/barnum-ceg3120:latest` to make sure the freshest version is used.
    - Grabs the newest copy of `barnum9/barnum-ceg3120:latest` to make sure the freshest version is used.
5. Runs a new container:
    - Names the container `angular-app`.
    - Runs it detached with `-d`, so it stays alive in the background.
    - Uses `--restart unless-stopped` so the container automatically restarts if the instance reboots, unless I manually stop it.  This was super annoying to figure out.
    - Maps port 4200 inside the container, to port 80 on the EC2 instance, so I can access the app at the EIP without needing to specify a port.
    - Names the container `angular-app`.
    - Runs it detached with `-d`, so it stays alive in the background.
    - Uses `--restart unless-stopped` so the container automatically restarts if the instance reboots, unless I manually stop it.  This was super annoying to figure out.
    - Maps port 4200 inside the container, to port 80 on the EC2 instance, so I can access the app at the EIP without needing to specify a port.

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

To verify that it actually stopped the old container and started the new one, I ran:

```
docker ps
```

Then, I confirmed the app was still loading correctly from the EC2's EIP.

---

### Configuring a Webhook Listener on EC2 Instance

To automate the deployment process when a new Docker image is pushed to DH, I set up a webhook listener on my EC2 instance using [`adnanh/webhook`](https://github.com/adnanh/webhook). This lets my EC2 instance auto-run my [update.sh](deployment/update.sh) script whenever it receives a webhook trigger with the correct secret.

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
| `webhook --version` | Checks the installed version of webhook | Confirms that the binary was installed correctly and is ready to use |

---

#### Webhook Hook Definition File

The hook ([hook.json](deployment/hook.json)) definition file lives in my `deployment` folder, and I manually copied it to my EC2 instance using `nano` since I didn't want to clone my whole repo onto the server.

[`hook.json`](deployment/hook.json)` contents:
```
[
  {
    "id": "refresh-container",
    "execute-command": "/home/ec2-user/deployment/update.sh",
    "command-working-directory": "/home/ec2-user/deployment"
  }
]
```

No shared secret is configured in the webhook definition file.  Access is restricted using AWS security group rules, allowing only GH webhook servers to interact with the EC2 instance on port 9000.

---

#### Configuring Payload Sender (GH)

I chose GH as the payload sender because my GH Action workflow builds and pushes new docker images whenever I push a semantic version tag to the repo.  Using GH as the webhook sender keeps the deployment process integrated with my version control, and CI/CD flow.

##### How I Enabled Webhook Sending:

- I went to the GH repo settings, then to webhooks
- I added the EC2 instance's EIP + port 9000, like: `http://34.194.10.16:9000/hooks/refresh-container`
- Selected application/json as the content type
- Disabled SSL verification (since we're not using HTTPS here)
- No secret configured, since security is handled through AWS Security Group rules

##### What Triggers the Payload:

The webhook in GH is currently configured to send a payload on any push event, this includes pushes to both branches and tags.  However, the actual deployment process only happens when a tag push occurs because:

- The GH Action workflow itself is set to trigger only on tag pushes matching `v*.*.*`.
- Even though the webhook sends a payload on every push, if no new tag is pushed, the workflow doesn't build a new docker image.
- The webhook will still POST to the EC2 on every push, but the [update.sh](deployment/update.sh) script will just pull the same image (if no new tag/image was pushed).  This means the webhook listener might get pinged more often than necessary, but actual redeployments only happen if a new docker image exists on DH.

---

#### Testing and Verification

After setting up the hook and opening the security group:

- I started the webhook listener manually:

```
webhook -hooks /home/ec2-user/deployment/hook.json -verbose
```

- Sent the curl request from another WSL instance

- Verified in the webhook logs that the request was received, and the `update.sh` script was triggered successfully.

Example output:

```
incoming HTTP POST request from 76.243.44.34:64450
refresh-container got matched
refresh-container hook triggered successfully
Pulling from barnum9/barnum-ceg3120
Image is up to date for barnum9/barnum-ceg3120:latest
finished handling refresh-container
```

> Example output from my manual curl test.

Confirmed that my container was refreshed and the new image was running using `docker ps` on the EC2.

---

### Configuring a Webhook Service on the EC2 Instance

To make sure my webhook listener `(adnanh/webhook)` starts automatically every time the EC2 instance boots up, and to avoid having to SSH in and run it manually, I created a systemd service file.

This service handles starting the webhook listener, pointing it at my [hook.json](deployment/hook.json) file that calls my [update.sh](deployment/update.sh) deployment script.

#### `webhook.service` File location and Contents

This is what my [webook.service](deployment/webhook.service) file contains:

```[Unit]
Description=Webhook Listener Service
After=network.target
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/webhook -hooks /home/ec2-user/deployment/hook.json -verbose
WorkingDirectory=/home/ec2-user/deployment
Restart=always
User=ec2-user

[Install]
WantedBy=multi-user.target
```

#### What This Does

| Section | Purpose |
|-|-|
| `[Unit]` | 	Describes the service and makes sure it waits until the network is up and docker is running before starting. |
| `[Service]` | Runs the webhook binary, pointing to my [hook.json](deployment/hook.json) file, and sets the pwd.  Restarts automatically if it ever stops so it doesn't break.  Runs as the `ec2-user`. |
| `[Install]` | Makes the service start on boot (enabled through systemd). |

#### How I Enabled and Started the Service

After creating the service file, I enabled it and started it with:

```
sudo systemctl daemon-reload
sudo systemctl enable webhook.service
sudo systemctl start webhook.service
```

This makes sure the service starts automatically on boot and also starts it immediately, without needing a reboot.

#### How I Verified it's Working

To check that the service was running and listening correctly:

```
sudo systemctl status webhook.service
```

It showed that the webhook process as actiuve and running.  The output also confirmed that it was loading the correct [hook.json](deployment/hook.json) file.

#### Confirming the Service Auto-Runs on Reboot

I manually tested that the service would still work after a reboot by:

1. Rebooting the EC2 instance:
```
sudo reboot
```


2. SSHing back in after the instance came back up.


3. Checking:
```
sudo systemctl status webhook.service
```
The service was running!

4. Triggered a webhook payload from GH to confirm the [update.sh](deployment/update.sh) script still ran correctly after reboot.

---

### Final End-to-End Deployment Test

To fully confirm the CI/CD pipeline and webhook integration were working correctly, I did an end-to-end deployment test:

1. Verified that the webhook listener service was running:
    - Used `sudo systemctl status webhook.service` to confirm the listener was active after reboot.
  
    - Used `sudo systemctl status webhook.service` to confirm the listener was active after reboot.
  
2. Made a small change to my Angular App locally:
    - I added a comment at the bottom of my `index.html` file like this:
    - I added a comment at the bottom of my `index.html` file like this:
  ```
  <!-- v1.1.1 -->
  ```
   - This gave me a visual indicator to confirm that the new deployment was using the latest pushed image.

   - This gave me a visual indicator to confirm that the new deployment was using the latest pushed image.

3. Committed the change and pushed it to GH:
```
git add .
git commit -m "added version comment to index.html"
git push
```
> Note: I am not sure what the actual commit message waas, I was frustrated, but you get the gist.


4. Tagged the commit and pushed the tag:
```
git tag -a v1.1.1 -m "I am losing my mind"
git push origin v1.1.1
```
> Note: this probably also wasn't the commit message, but might have been to be honest.


5. Watched the GH Action run:
    - Confirmed through the Actions tab that the workflow triggered on the tag push.
    - Saw in the workflow logs that it successfully build the docker image and pushed all the correct tags (`latest`, `1`, `1.1`, `1.1.1`) to DH.
    
    - Confirmed through the Actions tab that the workflow triggered on the tag push.
    - Saw in the workflow logs that it successfully build the docker image and pushed all the correct tags (`latest`, `1`, `1.1`, `1.1.1`) to DH.
    
6. Checked DH to confirm the newest images appeared with the correct tags.
  
  
7. Confirmed payload delivery to the EC2 webhook listener:
    - Used the Webhook delivery logs on GH to verify the payload was sent.
    - Also confirmed the webhook logs on the EC2 that the payload was recieved, matched the hook ID, and triggered [update.sh](deployment/update.sh).
    
    - Used the Webhook delivery logs on GH to verify the payload was sent.
    - Also confirmed the webhook logs on the EC2 that the payload was recieved, matched the hook ID, and triggered [update.sh](deployment/update.sh).
    
8. Verified container restart and redeployment:
    - Ran `docker ps` on the EC2 to confirm the container had restarted.
    - Confirmed that it was using the latest image.
    
    - Ran `docker ps` on the EC2 to confirm the container had restarted.
    - Confirmed that it was using the latest image.
    
9. Reloaded the app in the browser to verify the change went live:
    - Opened the EIP (`http://34.194.10.16`) in Firefox.
    - Used "View Page Source" to confirm that the version comment (`<!-- v1.1.1 -->`) was present at the bottom of the source code.

---   

#### Resources:

I also used a lot of the sources cited in my [Project 4 Documentation](README-CI.md) for this project, as they overlap.

##### AWS / EC2 Setup

- [Amazon SSD Info](https://aws.amazon.com/ebs/general-purpose/)
- [AL 2023 Documentation](https://docs.aws.amazon.com/linux/al2023/ug/what-is-amazon-linux.html)
- [Managing repos and OS updates on AL2023](https://docs.aws.amazon.com/linux/al2023/ug/managing-repos-os-updates.html)
- [EIP on AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
- [AWS VPC security group rules](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)


##### Docker Setup and Usage

- [Writing a dockerfile](https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile)
- [Docker CLI reference](https://docs.docker.com/reference/cli/docker/image/)
- [Published ports](https://docs.docker.com/engine/network/#published-ports)
- [Start containers automatically](https://docs.docker.com/engine/containers/start-containers-automatically/)
- [Installing docker on AL](https://docs.aws.amazon.com/linux/al2023/ug/install-docker.html)  


##### Webhook Setup

- [`adnanh/webhook` GH repo](https://github.com/adnanh/webhook)
- [Webhook parameters](https://github.com/adnanh/webhook/blob/master/docs/Webhook-Parameters.md)
- [Webhook examples](https://github.com/adnanh/webhook/blob/master/docs/Hook-Examples.md)
- [Systemd service file docs](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)


##### GH Webhooks and CI/CD Integration

- [GH webhooks Events and payloads](https://docs.github.com/en/webhooks/webhook-events-and-payloads)
- [Testing and troubleshooting GH webhooks](https://docs.github.com/en/webhooks/testing-and-troubleshooting-webhooks/troubleshooting-webhooks)
- [GH meta API (for IP ranges)](https://api.github.com/meta)
- [Building and pushing docker images with GH actions](https://github.com/marketplace/actions/build-and-push-docker-images)
- [GitHub actions docs](https://docs.github.com/en/actions)


##### Command References / Troubleshooting

- [dnf vs yum (Why I used dnf on AL2023)](https://cyberpanel.net/blog/dnf-vs-yum)
- [Using docker Without sudo](https://askubuntu.com/questions/477551/how-can-i-use-docker-without-sudo)
- [Understanding `chmod +x` perms](https://askubuntu.com/questions/443789/what-does-chmod-x-filename-do-and-how-do-i-use-it)
- [How to extract .tar.gz files](https://linuxize.com/post/how-to-extract-unzip-tar-gz-file/)
- [curl command guide](https://ec.haxx.se/usingcurl/downloads/)


##### Documentation and Diagram Tools

- [Lucidchart](https://www.lucidchart.com/pages)
- [Markdown guide](https://www.markdownguide.org/)
- [ChatGPT](https://www.chatgpt.com/)
  - "Can you explain how webhook listeners work with GitHub payloads?"
  - "How can I make port 9000 open on my EC2 instance to just gihub and not the entire world so my webhook works?"
  - "how can I make Docker automatically restart containers after a system reboot?"
  - "What is the easiest way to configure systemd services to autostart at boot on Amazon Linux?"
  - "how do I troubleshoot a webhook not triggering my script correctly I am losing my mind"