pipeline {
    agent any

    parameters {
        choice(
            name: 'SERVICE',
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
            description: 'Service to build'
        )

        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )

        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Optional image tag (defaults to build number)'
        )
    }

    environment {
        AWS_REGION  = 'us-east-1'
        ECR_ACCOUNT = '163447728448'
        ECR_URL     = "${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"

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

        stage('Build & Push') {
            matrix {
                axes {
                    axis {
                        name 'SERVICE_NAME'
                        values(
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
                        )
                    }
                }

                when {
                    expression {
                        params.SERVICE == 'all' || params.SERVICE == SERVICE_NAME
                    }
                }

                stages {

                    stage('Build & Push Image') {
                        steps {
                            script {
                                def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER

                                def serviceDirMap = [
                                    adservice               : 'src/adservice',
                                    cartservice             : 'cartservice/src',
                                    paymentservice          : 'src/paymentservice',
                                    checkoutservice         : 'src/checkoutservice',
                                    currencyservice         : 'src/currencyservice',
                                    emailservice            : 'src/emailservice',
                                    frontend                : 'src/frontend',
                                    loadgenerator           : 'src/loadgenerator',
                                    productcatalogservice   : 'src/productcatalogservice',
                                    recommendationservice   : 'src/recommendationservice',
                                    shippingservice         : 'src/shippingservice'
                                ]

                                def serviceDir = serviceDirMap[SERVICE_NAME]

                                if (!fileExists("${serviceDir}/Dockerfile")) {
                                    echo "⚠️ No Dockerfile for ${SERVICE_NAME}, skipping"
                                    return
                                }

                                dir(serviceDir) {
                                    sh "docker build -t ${SERVICE_NAME}:${tag} ."

                                    withCredentials([[
                                        $class: 'AmazonWebServicesCredentialsBinding',
                                        credentialsId: 'aws-credentials'
                                    ]]) {
                                        sh """
                                            aws ecr get-login-password --region ${AWS_REGION} \
                                            | docker login --username AWS --password-stdin ${ECR_URL}

                                            docker tag ${SERVICE_NAME}:${tag} ${ECR_URL}/${SERVICE_NAME}:${tag}
                                            docker push ${ECR_URL}/${SERVICE_NAME}:${tag}
                                        """
                                    }
                                }
                            }
                        }
                    }

                    stage('Update Manifest') {
                        when {
                            expression { SERVICE_NAME != 'loadgenerator' }
                        }
                        steps {
                            script {
                                def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER

                                dir('kubernetes-files') {
                                    withCredentials([
                                        string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')
                                    ]) {
                                        sh """
                                            git config user.email "${GIT_EMAIL}"
                                            git config user.name "${GIT_USER_NAME}"

                                            sed -i "s#image:.*#image: ${ECR_URL}/${SERVICE_NAME}:${tag}#g" ${SERVICE_NAME}.yaml

                                            git add ${SERVICE_NAME}.yaml
                                            git commit -m "chore(${ENV}): update ${SERVICE_NAME} to ${tag}" || echo "No changes"
                                            git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:master
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

    post {
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo '✅ Pipeline completed successfully'
        }
        failure {
            echo '❌ Pipeline failed'
        }
    }
}
