pipeline {
    agent any

    parameters {
        choice(
            name: 'SERVICES',
            choices: ['all', 'adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice'],
            description: 'Which services to build'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Optional image tag (defaults to BUILD_NUMBER)'
        )
    }

    environment {
        AWS_REGION  = "us-east-1"
        ECR_ACCOUNT = "163447728448"
        ECR_URL     = "${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        GIT_USER_NAME = "JFKTBonny"
        GIT_EMAIL     = "jkamkotoyip@yahoo.com"
        GIT_REPO_NAME = "Microservices-E-Commerce-eks-project"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Microservices') {
            matrix {
                axes {
                    axis {
                        name 'SERVICE'
                        values 'adservice', 'cartservice', 'paymentservice'
                    }
                }

                when {
                    expression {
                        params.SERVICES == 'all' ||
                        params.SERVICES == env.SERVICE
                    }
                }

                stages {

                    stage('Build Image') {
                        steps {
                            dir("src/${SERVICE}") {
                                sh '''
                                  set -e
                                  TAG=${IMAGE_TAG:-$BUILD_NUMBER}
                                  docker build -t ${SERVICE}:${TAG} .
                                '''
                            }
                        }
                    }

                    stage('Push to ECR') {
                        steps {
                            withCredentials([
                                [$class: 'AmazonWebServicesCredentialsBinding',
                                 credentialsId: 'aws-jenkins']
                            ]) {
                                sh '''
                                  set -e
                                  TAG=${IMAGE_TAG:-$BUILD_NUMBER}

                                  aws ecr get-login-password --region ${AWS_REGION} \
                                  | docker login --username AWS --password-stdin ${ECR_URL}

                                  docker tag ${SERVICE}:${TAG} ${ECR_URL}/${SERVICE}:${TAG}
                                  docker push ${ECR_URL}/${SERVICE}:${TAG}
                                '''
                            }
                        }
                    }

                    stage('Update Kubernetes Manifest') {
                        steps {
                            dir('kubernetes-files') {
                                withCredentials([
                                    string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')
                                ]) {
                                    sh '''
                                      set -e
                                      TAG=${IMAGE_TAG:-$BUILD_NUMBER}

                                      git config user.email "${GIT_EMAIL}"
                                      git config user.name "${GIT_USER_NAME}"

                                      sed -i "s#image:.*#image: ${ECR_URL}/${SERVICE}:${TAG}#g" ${SERVICE}.yaml

                                      git add ${SERVICE}.yaml
                                      git commit -m "chore(${ENV}): update ${SERVICE} image to ${TAG}" || echo "No changes"

                                      git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:master
                                    '''
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Matrix pipeline completed successfully"
        }
        cleanup {
            sh 'docker image prune -f || true'
        }
    }
}
