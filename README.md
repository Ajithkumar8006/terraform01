jobs:
  gcp-auth:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          token_format: access_token
          workload_identity_provider: ${{ inputs.workload_identity_provider }}
          service_account: ${{ inputs.service_account_email }}

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v1

      - name: Configure Docker to use Artifact Registry
        run: |
          gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

      - name: Pull Docker Image from Artifact Registry
        run: |
          docker pull us-central1-docker.pkg.dev/apigee-test-0002-demo/my-artifact-repo/hello-world-image:latest

      - name: List Pulled Docker Image
        run: |
          echo "Pulled image:"
          docker images | grep hello-world-image || echo "Image not found"
