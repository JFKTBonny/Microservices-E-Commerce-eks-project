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

        stage('Validate Services') {
            steps {
                script {
                    // List services with Dockerfiles
                    def servicesWithDockerfile = []
                    def serviceDirs = ['adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice']
                    
                    serviceDirs.each { service ->
                        if (fileExists("${service}/Dockerfile")) {
                            servicesWithDockerfile.add(service)
                            echo "✅ Found Dockerfile in ${service}/"
                        } else {
                            echo "❌ No Dockerfile in ${service}/"
                        }
                    }
                    
                    env.SERVICES_WITH_DOCKERFILE = servicesWithDockerfile.join(',')
                    echo "Services ready to build: ${env.SERVICES_WITH_DOCKERFILE}"
                }
            }
        }

        stage('Build & Push Microservices') {
            when {
                expression { params.SERVICES == 'all' || params.SERVICES in env.SERVICES_WITH_DOCKERFILE.split(',') }
            }
            matrix {
                axes {
                    axis {
                        name 'SERVICE'
                        values "${env.SERVICES_WITH_DOCKERFILE}"
                    }
                }
                stages {
                    stage('Build Image') {
                        when {
                            expression { params.SERVICES == 'all' || params.SERVICES == env.SERVICE }
                        }
                        steps {
                            script {
                                dir("${SERVICE}") {
                                    // Check cartservice special case
                                    def buildContext = '.'
                                    if (SERVICE == 'cartservice' && fileExists('src/Dockerfile')) {
                                        buildContext = 'src'
                                    } else if (!fileExists('Dockerfile')) {
                                        error "No Dockerfile found in ${SERVICE}/${buildContext}"
                                    }
                                    
                                    echo "Building ${SERVICE} from ${buildContext}"
                                    sh """
                                        docker build -t ${ECR_URL}/${SERVICE}:${TAG} ${buildContext}
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
            echo "❌ Pipeline failed - check which services have Dockerfiles"
        }
    }
}
