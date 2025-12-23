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
        AWS_REGION  = 'us-east-1'
        ECR_ACCOUNT = '163447728448'
        ECR_URL     = "${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        TAG         = "${params.IMAGE_TAG ?: env.BUILD_NUMBER}"
        
        GIT_USER_NAME = 'JFKTBonny'
        GIT_EMAIL     = 'jkamkotoyip@yahoo.com'
        GIT_REPO_NAME = 'Microservices-E-Commerce-eks-project'
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
                        values 'adservice', 'cartservice', 'paymentservice', 
                               'checkoutservice', 'currencyservice', 'emailservice', 
                               'frontend', 'loadgenerator', 'productcatalogservice', 
                               'recommendationservice', 'shippingservice'
                    }
                }
                stages {
                    stage('Build Image') {
                        when {
                            expression { params.SERVICES == 'all' || params.SERVICES == env.SERVICE }
                        }
                        steps {
                            dir("${SERVICE}") {
                                script {
                                    def buildDir = (SERVICE == 'cartservice') ? 'Microservices-E-Commerce-eks-project/src' : '.'
                                    sh """
                                        docker build -t ${ECR_URL}/${SERVICE}:${TAG} ${buildDir}
                                    """
                                }
                            }
                        }
                    }
                    stage('Push to ECR') {
                        when {
                            expression { params.SERVICES == 'all' || params.SERVICES == env.SERVICE }
                        }
                        steps {
                            script {
                                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                    sh """
                                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
                                        docker tag ${ECR_URL}/${SERVICE}:${TAG} ${ECR_URL}/${SERVICE}:${TAG}
                                        docker push ${ECR_URL}/${SERVICE}:${TAG}
                                    """
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Update Kubernetes Manifests') {
            when {
                expression { params.SERVICES != 'loadgenerator' }
            }
            steps {
                dir('kubernetes-files') {
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                            git checkout master || git checkout -b update-manifests-${BUILD_NUMBER}
                            git config user.email "${GIT_EMAIL}"
                            git config user.name "${GIT_USER_NAME}"
                            
                            services="adservice cartservice paymentservice checkoutservice currencyservice emailservice frontend productcatalogservice recommendationservice shippingservice"
                            
                            for service in $services; do
                                yaml_file="${service}.yaml"
                                if [ -f "$yaml_file" ]; then
                                    sed -i "s|image:.*|image: ${ECR_URL}/${service}:${TAG}|g" "$yaml_file"
                                    git add "$yaml_file"
                                fi
                            done
                            
                            if git diff --staged --quiet; then
                                echo "No manifest changes to commit"
                            else
                                git commit -m "chore(${ENV}): update ${SERVICES} images to ${TAG} [skip ci]" || true
                                git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:master || true
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo "✅ Pipeline completed successfully for ${params.SERVICES} in ${params.ENV}"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}
