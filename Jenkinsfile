pipeline {
    agent any

    parameters {
        choice(
            name: 'SERVICES',
            choices: [
                'all', 
                'adservice', 
                'cartservice', 
                'paymentservice', 
                'checkoutservice', 
                'currencyservice', 
                'emailservice', 
                'frontend', 
                'loadgenerator', 
                'productcatalogservice', 
                'recommendationservice', 
                'shippingservice'
            ],
            description: 'Which services to build'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: "$BUILD_NUMBER",
            description: 'Optional image tag (defaults to the build number)'
        )
        choice(
            name: 'MAX_PARALLEL',
            choices: ['1', '2', '3', '4'],
            description: 'Maximum number of parallel builds'
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
            parallel {
                stage('Build & Push Services') {
                    matrix {
                        axes {
                            axis {
                                name 'SERVICE'
                                values 'adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice',
                                       'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice',
                                       'recommendationservice', 'shippingservice'
                            }
                        }
                        when {
                            expression {
                                params.SERVICES == 'all' || params.SERVICES == env.SERVICE
                            }
                        }

                        stages {
                            stage('Build Image') {
                                steps {
                                    script {
                                        def dockerfilePath = getDockerfilePath(env.SERVICE)
                                        if (checkDockerfileExists(env.SERVICE)) {
                                            sh """
                                                TAG=${IMAGE_TAG:-$BUILD_NUMBER}
                                                echo "Building ${SERVICE} with tag ${TAG}"
                                                docker build -f ${dockerfilePath} -t ${SERVICE}:${TAG} .
                                            """
                                        }
                                    }
                                }
                            }

                            stage('Push to ECR') {
                                steps {
                                    script {
                                        if (checkDockerfileExists(env.SERVICE)) {
                                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                                sh """
                                                    TAG=${IMAGE_TAG:-$BUILD_NUMBER}
                                                    echo "Logging in to ECR and pushing ${SERVICE}:${TAG}"
                                                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
                                                    docker tag ${SERVICE}:${TAG} ${ECR_URL}/${SERVICE}:${TAG}
                                                    docker push ${ECR_URL}/${SERVICE}:${TAG}
                                                """
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Update Kubernetes Manifests') {
            steps {
                dir('kubernetes-files') {
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                            git checkout master
                            git config user.email "${GIT_EMAIL}"
                            git config user.name "${GIT_USER_NAME}"

                            for service in adservice cartservice paymentservice checkoutservice currencyservice \
                            emailservice frontend loadgenerator productcatalogservice recommendationservice shippingservice
                            do
                                yaml_file="${service}.yaml"
                                if [ -f "$yaml_file" ]; then
                                    sed -i "s#image:.*#image: ${ECR_URL}/${service}:${IMAGE_TAG:-$BUILD_NUMBER}#g" "$yaml_file"
                                    git add "$yaml_file"
                                fi
                            done

                            git commit -m "chore(${ENV}): update service images" || echo "No changes to commit"
                            git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git master
                        '''
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

// Helper functions
def getDockerfilePath(service) {
    return service == 'cartservice' ? 'cartservice/src/Dockerfile' : "src/${service}/Dockerfile"
}

def checkDockerfileExists(service) {
    def dockerfilePath = getDockerfilePath(service)
    if (!fileExists(dockerfilePath)) {
        echo "⚠️ Dockerfile not found for ${service}, skipping build."
        return false
    }
    return true
}