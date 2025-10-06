# Ingestion Service

# Execute Tests locally

1. docker build -t ingestion:0.1.0-test . --target testrunner
1. docker run --name ingestiontests --rm -d ingestion:0.1.0-test
1. docker cp ingestiontests:/usr/src/app/target/surefire-reports/ $(pwd)/.
1. docker stop ingestiontests
