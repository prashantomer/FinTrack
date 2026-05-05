.PHONY: dev

dev:
	foreman start 2>&1 | tee logs/foreman.log
