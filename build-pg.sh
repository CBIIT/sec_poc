rm -rf postgres_data_dir
docker buildx build --platform linux/amd64 -t pg2   -f docker/pg/Dockerfile . --output type=docker $@