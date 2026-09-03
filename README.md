# AWS Services — Jenkins CI/CD Exercise

This repository contains a small Node.js/Express application and a Jenkins pipeline that tests, containerizes, publishes, and deploys it to an EC2 instance.

## Application

The application is in [`app/`](app/). It serves a simple profile page on port `3000`.

```bash
cd app
npm ci
npm test
npm start
```

Open `http://localhost:3000` after starting the application.

## Container image

[`app/Dockerfile`](app/Dockerfile) uses `node:24-alpine`, installs dependencies from the lockfile, and runs `server.js`.

Build and run it locally:

```bash
docker build -t ronkaiser86/myapp:local ./app
docker run --rm -p 3000:3000 ronkaiser86/myapp:local
```

The image listens on port `3000`. [`docker-compose.yaml`](docker-compose.yaml) maps that port from the EC2 host to the container.

## Jenkins pipeline

[`Jenkinsfile`](Jenkinsfile) uses the `jenkins-shared-library` library and runs the following stages:

1. **Increment version** — increments the minor version in `app/package.json` and creates an image tag in the form `<version>-<build-number>`.
2. **Run tests** — installs Node dependencies and runs Jest.
3. **Build and push Docker image** — builds `ronkaiser86/myapp:<version>-<build-number>` and pushes it to Docker Hub.
4. **Deploy to EC2** — transfers the Compose configuration and deployment script, then starts the new image remotely.
5. **Commit to Git** — commits the version-file changes made during the build and pushes them to `main`.

Only the test stage runs for non-`main` branches. Versioning, image publishing, deployment, and the Git commit occur only on `main`.

## Required Jenkins configuration

Configure these Jenkins tools and credentials before running the job:

| Item | Jenkins ID / name | Purpose |
| --- | --- | --- |
| Node.js tool | `node` | Runs npm and Jest |
| GitHub credentials | `github-credentials` | Checks out the application and shared library |
| Docker Hub credentials | Used by `dockerLogin()` | Publishes `ronkaiser86/myapp` |
| SSH private key | `ec2-server-key` | Connects as `ec2-user` to the EC2 instance |
| GitHub token | `github-pat-devops-08` | Pushes the Jenkins version-bump commit |

The Jenkins agent must have Docker, Git, Node.js, and the SSH Agent plugin available. The Jenkins job also needs permission to access the Docker daemon.

## GitHub webhook firewall access

GitHub must be able to reach the Jenkins webhook endpoint to trigger builds. Retrieve GitHub's current webhook source CIDR ranges with:

```bash
curl -s https://api.github.com/meta | jq -r '.hooks[]'
```

Allow **inbound TCP port `8080`** to the Jenkins server only from every returned CIDR. Do not open port `8080` to all internet addresses. GitHub can update these ranges, so retrieve the list again when reviewing or recreating firewall rules.

## EC2 deployment

[`server-cmds.sh`](server-cmds.sh) receives the image tag from Jenkins, expands it to the full Docker Hub image name, and runs Compose:

```bash
export IMAGE="ronkaiser86/myapp:<tag>"
docker-compose -f docker-compose.yaml up --detach
```

On the EC2 instance, Docker and Docker Compose must be installed, and the `ec2-user` account must be able to run Docker commands. After deployment, the application is available on port `3000` of the EC2 instance.

## SSH host-key maintenance

If Jenkins reports **REMOTE HOST IDENTIFICATION HAS CHANGED**, do not ignore it. Verify the EC2 instance's ED25519 host-key fingerprint through a trusted connection:

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Then, inside the Jenkins controller container (where `/var/jenkins_home` exists), replace only the stale entry:

```bash
mkdir -p /var/jenkins_home/.ssh
touch /var/jenkins_home/.ssh/known_hosts
ssh-keygen -f /var/jenkins_home/.ssh/known_hosts -R <EC2_IP>
ssh-keyscan -H -t ed25519 <EC2_IP> >> /var/jenkins_home/.ssh/known_hosts
chown -R jenkins:jenkins /var/jenkins_home/.ssh
chmod 700 /var/jenkins_home/.ssh
chmod 600 /var/jenkins_home/.ssh/known_hosts
```

Confirm that the scanned fingerprint matches the verified fingerprint before accepting it. Once the key is stored, remove `-o StrictHostKeyChecking=no` from the `scp` and `ssh` commands in the Jenkinsfile so future key changes fail safely.

## Project layout

```text
app/                  Node.js application, tests, Dockerfile, and Docker ignore rules
Jenkinsfile           CI/CD pipeline definition
docker-compose.yaml   Runtime service and port mapping for EC2
server-cmds.sh        Remote deployment command invoked by Jenkins
```
