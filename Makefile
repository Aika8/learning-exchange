.PHONY: test dev clean

# Run every test in the repo (today: backend Gradle modules).
test:
	./gradlew test

# Start the platform locally. Until the backend exists (M1) this is the order-book REPL.
dev:
	./gradlew -q --console=plain :backend:repl:run

clean:
	./gradlew clean
