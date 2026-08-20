// Jenkinsfile - CI/CD pipeline for kanban-style-task-manager
//
// Flow: GitHub -> Jenkins -> Build -> Docker Image -> ECR -> EC2 -> Docker Deployment -> Validation
//
// Required Jenkins plugins: Git, Docker Pipeline, Credentials Binding
// Required Jenkins credential (Kind: "Username and password"):
//   ID: aws-ecr-creds
//   Username: <AWS_ACCESS_KEY_ID>
//   Password: <AWS_SECRET_ACCESS_KEY>
//   (Use an IAM user that only has AmazonEC2ContainerRegistryPowerUser - nothing broader.)
//
// EDIT the values in the `environment` block below for your own AWS account.

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        AWS_REGION      = 'ap-south-1'                                   // <-- change to your region
        AWS_ACCOUNT_ID  = '123456789012'                                 // <-- change to your AWS account ID
        ECR_REPO_NAME   = 'kanban-app'
        ECR_REGISTRY    = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME      = "${ECR_REGISTRY}/${ECR_REPO_NAME}"
        GIT_SHA_SHORT   = "${GIT_COMMIT?.take(7) ?: 'unknown'}"
        IMAGE_TAG_BUILD = "${IMAGE_NAME}:${BUILD_NUMBER}"
        IMAGE_TAG_SHA   = "${IMAGE_NAME}:${GIT_SHA_SHORT}"
        APP_HOST_PORT   = '8081'   // the app port opened in the EC2 Security Group
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHA_SHORT   = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.IMAGE_TAG_SHA   = "${IMAGE_NAME}:${env.GIT_SHA_SHORT}"
                }
                echo "Building commit ${env.GIT_SHA_SHORT} as build #${env.BUILD_NUMBER}"
            }
        }

        stage('Docker Build & Tag') {
            steps {
                sh """
                    docker build -t ${IMAGE_TAG_BUILD} -t ${env.IMAGE_TAG_SHA} .
                """
            }
        }

        stage('Login & Push to ECR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-ecr-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        docker push ${IMAGE_TAG_BUILD}
                        docker push ${env.IMAGE_TAG_SHA}
                    """
                }
            }
        }

        stage('Deploy to EC2 (blue-green)') {
            steps {
                sh """
                    chmod +x deploy/deploy.sh deploy/rollback.sh
                    APP_HOST_PORT=${APP_HOST_PORT} ./deploy/deploy.sh ${IMAGE_TAG_BUILD}
                """
            }
        }

        stage('Health Check & Validation') {
            steps {
                sh """
                    echo 'Container status:'
                    docker ps --filter name=kanban-app
                    echo 'Public endpoint check:'
                    curl -fsS http://localhost:${APP_HOST_PORT}/healthz
                    curl -fsS -o /dev/null -w 'HTTP %{http_code}\\n' http://localhost:${APP_HOST_PORT}/
                """
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} (${env.GIT_SHA_SHORT}) deployed and validated successfully."
        }
        failure {
            echo "Build #${env.BUILD_NUMBER} FAILED. Attempting automatic rollback to last known-good image..."
            sh """
                chmod +x deploy/rollback.sh || true
                APP_HOST_PORT=${APP_HOST_PORT} ./deploy/rollback.sh || echo 'Rollback script reported an issue - check manually.'
            """
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
