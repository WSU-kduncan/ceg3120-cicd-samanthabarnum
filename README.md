# CEG 3120 Final Project Repository

This repo contains my work for **Project 4 (Continuous Integration)** and **Project 5 (Continuous Deployment)**.  The goal of these projects was to containerize an Angular app using Docker, set up CI to automatically build and push images to DH, and then implement CD to automatically redeploy the container on an AWS EC2 instance whenever a new version tag is pushed.

The documentation for each part is broken out into its own README file.

---

## Documentation

### [README-CI.md](README-CI.md)
Covers the **Continuous Integration** setup from Project 4:
- How the Docker image is built from my Angular application.
- How the GH Actions workflow pushes versioned images to DH.
- Testing and validating the CI process.

---

### [README-CD.md](README-CD.md)
Covers the **Continuous Deployment** setup from Project 5:
- How the EC2 instance is configured to receive webhook payloads from GH.
- How the instance automatically pulls the latest Docker image and redeploys the container.
- Webhook listener setup, systemd service configuration, and security group rules.
- End-to-end testing and validation of the full deployment pipeline.