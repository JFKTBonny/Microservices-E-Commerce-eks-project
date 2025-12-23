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
                        values 'adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice'
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
                                def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER

                                def dockerfilePath = SERVICE == 'cartservice' ? 'src/cartservice/src/Dockerfile' : "src/${SERVICE}/Dockerfile"
                                if (fileExists(dockerfilePath)) {
                                    sh """
                                        
                                        docker build -f ${dockerfilePath} -t ${SERVICE}:${TAG} .
                                    """
                                } else {
                                    echo "⚠️ Dockerfile not found for ${SERVICE}, skipping build."
                                }
                            }
                        }
                    }

                    stage('Push to ECR') {
                        steps {
                            script {
                                def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER

                                def dockerfilePath = SERVICE == 'cartservice' ? 'cartservice/src/Dockerfile' : "src/${SERVICE}/Dockerfile"
                                if (fileExists(dockerfilePath)) {
                                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                        sh """
                                            
                                            aws ecr get-login-password --region ${AWS_REGION} \
                                            | docker login --username AWS --password-stdin ${ECR_URL}

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

        stage('Update Kubernetes Manifests') {
            steps {
                dir('kubernetes-files') {
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                            git checkout master
                            git config user.email "${GIT_EMAIL}"
                            git config user.name "${GIT_USER_NAME}"

                            for service in adservice cartservice paymentservice checkoutservice currencyservice emailservice frontend loadgenerator productcatalogservice recommendationservice shippingservice
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
