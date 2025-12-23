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
            defaultValue: '',
            description: 'Optional image tag (defaults to BUILD_NUMBER)'
        )
    }

    environment {
        AWS_REGION   = "us-east-1"
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

        stage('Build & Push Services') {
            steps {
                script {

                    def TAG = params.IMAGE_TAG?.trim()
                    if (!TAG) {
                        TAG = env.BUILD_NUMBER
                    }

                    /*
                      service : [
                        dockerfile path,
                        build context,
                        ecr repo name
                      ]
                    */
                    def services = [
                        adservice: [
                            dockerfile: 'src/adservice/Dockerfile',
                            context   : 'src/adservice',
                            repo      : 'adservice'
                        ],
                        cartservice: [
                            dockerfile: 'cartservice/src/Dockerfile',
                            context   : 'cartservice/src',
                            repo      : 'cartservice'
                        ],
                        paymentservice: [
                            dockerfile: 'src/paymentservice/Dockerfile',
                            context   : 'src/paymentservice',
                            repo      : 'paymentservice'
                        ],
                        checkoutservice: [
                            dockerfile: 'src/checkoutservice/Dockerfile',
                            context   : 'src/checkoutservice',
                            repo      : 'checkoutservice'
                        ],
                        currencyservice: [
                            dockerfile: 'src/currencyservice/Dockerfile',
                            context   : 'src/currencyservice',
                            repo      : 'currencyservice'
                        ],
                        emailservice: [
                            dockerfile: 'src/emailservice/Dockerfile',
                            context   : 'src/emailservice',
                            repo      : 'emailservice'
                        ],
                        frontend: [
                            dockerfile: 'src/frontend/Dockerfile',
                            context   : 'src/frontend',
                            repo      : 'frontend'
                        ],
                        loadgenerator: [
                            dockerfile: 'src/loadgenerator/Dockerfile',
                            context   : 'src/loadgenerator',
                            repo      : 'loadgenerator'
                        ],
                        productcatalogservice: [
                            dockerfile: 'src/productcatalogservice/Dockerfile',
                            context   : 'src/productcatalogservice',
                            repo      : 'productcatalogservice'
                        ],
                        recommendationservice: [
                            dockerfile: 'src/recommendationservice/Dockerfile',
                            context   : 'src/recommendationservice',
                            repo      : 'recommendationservice'
                        ],
                        shippingservice: [
                            dockerfile: 'src/shippingservice/Dockerfile',
                            context   : 'src/shippingservice',
                            repo      : 'shippingservice'
                        ]
                    ]

                    def selected = (params.SERVICES == 'all') ?
                        services.keySet() :
                        [params.SERVICES]

                    def jobs = [:]

                    selected.each { svc ->
                        jobs[svc] = {
                            buildAndPush(
                                svc,
                                services[svc].dockerfile,
                                services[svc].context,
                                services[svc].repo,
                                TAG
                            )
                        }
                    }

                    parallel jobs
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
    }
}

/* =============================
   Helper Function
   ============================= */

def buildAndPush(service, dockerfile, context, repo, tag) {

    if (!fileExists(dockerfile)) {
        echo "⚠️ Dockerfile not found for ${service}, skipping"
        return
    }

    echo "🚀 Building ${service}:${tag}"

    sh """
        docker build \
          -f ${dockerfile} \
          -t ${repo}:${tag} \
          --build-arg ENV=${params.ENV} \
          --label service=${service} \
          --label build=${tag} \
          ${context}
    """

    withCredentials([
        [$class: 'AmazonWebServicesCredentialsBinding',
         credentialsId: 'aws-credentials']
    ]) {
        sh """
            aws ecr get-login-password --region ${env.AWS_REGION} \
            | docker login --username AWS --password-stdin ${env.ECR_URL}

            docker tag ${repo}:${tag} ${env.ECR_URL}/${repo}:${tag}
            docker push ${env.ECR_URL}/${repo}:${tag}
        """
    }

    echo "✅ ${service} pushed to ECR"
}
