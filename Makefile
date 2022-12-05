all: base dist

base:
	docker build -t sd-deps-base -f Dockerfile.base .
dist:
	docker build -t sd-deps-base -f Dockerfile.dist .

clean:
	docker system prune --all