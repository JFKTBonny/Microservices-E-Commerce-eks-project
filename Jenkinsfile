pipeline {
    agent any

    parameters {
        choice(
            name: 'SERVICES',
            choices: [
                'all',
                'adservice',
                'cartservice',
                'checkoutservice',
                'currencyservice',
                'emailservice',
                'frontend',
                'loadgenerator',
                'paymentservice',
                'productcatalogservice',
                'recommendationservice',
                'shippingservice'
            ],
            description: 'Service(s) to process'
        )

        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )

        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Optional Docker image tag (defaults to build number)'
        )
    }

    environment {
        DOCKERHUB_ORG = "jfktbonny"   // 👈 your Docker Hub username/org
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test → Build → Push') {
            steps {
                script {
                    def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER

                    def services = params.SERVICES == 'all'
                        ? serviceConfig.keySet()
                        : [params.SERVICES]

                    def parallelSteps = [:]

                    services.each { svc ->
                        parallelSteps[svc] = {
                            processService(svc, tag)
                        }
                    }

                    parallel parallelSteps
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}

/* ================================
   SERVICE CONFIGURATION
================================ */

def serviceConfig = [
    adservice: [
        dir: 'src/adservice',
        test: { env -> "./gradlew test" }
    ],

    cartservice: [
        dir: 'src/cartservice',
        test: { env -> "dotnet test" }
    ],

    checkoutservice: [
        dir: 'src/checkoutservice',
        test: { env -> "go test ./..." }
    ],

    frontend: [
        dir: 'src/frontend',
        test: { env -> "go test ./..." }
    ],

    productcatalogservice: [
        dir: 'src/productcatalogservice',
        test: { env -> "go test ./..." }
    ],

    shippingservice: [
        dir: 'src/shippingservice',
        test: { env -> "go test ./..." }
    ],

    currencyservice: [
        dir: 'src/currencyservice',
        test: { env -> "npm install && npm test" }
    ],

    paymentservice: [
        dir: 'src/paymentservice',
        test: { env -> "npm install && npm test" }
    ],

    emailservice: [
        dir: 'src/emailservice',
        test: { env -> "pip install -r requirements.txt && pytest" }
    ],

    recommendationservice: [
        dir: 'src/recommendationservice',
        test: { env -> "pip install -r requirements.txt && pytest" }
    ],

    loadgenerator: [
        dir: 'src/loadgenerator',
        test: { env -> "echo 'Skipping tests for loadgenerator'" }
    ]
]

/* ================================
   SERVICE EXECUTION
================================ */

def processService(service, tag) {

    def cfg = serviceConfig[service]

    if (!cfg) {
        echo "⚠️ No config for ${service}, skipping"
        return
    }

    dir(cfg.dir) {

        echo "🚀 Processing ${service} (${params.ENV})"

        /* ---------- TEST ---------- */
        if (params.ENV != 'prod') {
            echo "🧪 Running tests for ${service}"
            sh cfg.test(params.ENV)
        } else {
            echo "🧪 PROD → skipping heavy tests"
        }

        /* ---------- BUILD ---------- */
        if (!fileExists('Dockerfile')) {
            error "❌ Dockerfile not found for ${service}"
        }

        sh """
            docker build -t ${service}:${tag} .
        """

        /* ---------- PUSH ---------- */
        withCredentials([usernamePassword(
            credentialsId: 'dockerhub-creds',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
        )]) {
            sh """
                echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                docker tag ${service}:${tag} ${DOCKERHUB_ORG}/${service}:${tag}
                docker push ${DOCKERHUB_ORG}/${service}:${tag}
            """
        }

        echo "✅ ${service}:${tag} pushed to Docker Hub"
    }
}
