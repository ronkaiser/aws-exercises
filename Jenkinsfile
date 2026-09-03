@Library('jenkins-shared-library') _

pipeline {
    agent any
    tools {
        nodejs 'node'
    }
    environment {
        APP_DIR = 'app'
    }
    stages {
        stage("increment version"){
            when {
                expression {
                    return env.BRANCH_NAME == "main"
                }
            }
            steps {
                script {
                    dir(env.APP_DIR) {
                        incrementversion()
                    }
                }
            }
        }
        stage("run tests") {
            steps {
                dir(env.APP_DIR) {
                    runtests()
                }
            }
        }
        stage("build and push docker image") {
            when {
                expression {
                    return env.BRANCH_NAME == "main"
                }
            }
            steps{
                dir(env.APP_DIR) {
                    script {
                        def imageName = "ronkaiser86/myapp:${env.IMAGE_NAME}"
                        buildImage(imageName)
                        dockerLogin()
                        dockerPush(imageName)
                    }
                }
            }
        }
        stage('deploy to EC2') {
            when {
                expression {
                    return env.BRANCH_NAME == "main"
                }
            }
            steps {
                script {
                   def shellCmd = "bash ./server-cmds.sh ${IMAGE_NAME}"
                   def ec2Instance = "ec2-user@18.195.253.19"

                   sshagent(['ec2-server-key']) {
                       sh "scp -o StrictHostKeyChecking=no server-cmds.sh ${ec2Instance}:/home/ec2-user"
                       sh "scp -o StrictHostKeyChecking=no docker-compose.yaml ${ec2Instance}:/home/ec2-user"
                       sh "ssh -o StrictHostKeyChecking=no ${ec2Instance} ${shellCmd}"
                   }     
                }
            }
        }
        stage("commit to git") {
            when {
                expression {
                    return env.BRANCH_NAME == "main"
                }
            }
            steps {
                script {
                    commitToGit(
                        'https://github.com/ronkaiser/aws-exercises.git',
                        'main',
                        'github-pat-devops-08'
                    )
                }
            }
        }
    }
}